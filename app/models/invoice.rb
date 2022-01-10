# frozen_string_literal: true

# Invoice model
# file: app/models/invoice.rb

class Invoice < ApplicationRecord
  include DirtyTransactionTracker

  attr_accessor :callbacks_disabled

  belongs_to :invoiceable, polymorphic: true
  belongs_to :payer, polymorphic: true
  belongs_to :collector, polymorphic: true

  has_many :line_items
  has_many :stripe_charges
  has_many :refunds
  
  has_many :line_item_reductions,
    through: :line_items
    
  before_validation :set_number,
    on: :create,
    unless: Proc.new{|i| i.callbacks_disabled }
  before_create :mark_line_items_priced_in,
    unless: Proc.new{|i| i.callbacks_disabled }
  before_update :set_status,
    unless: Proc.new{|i| i.will_save_change_to_attribute?('status') || i.callbacks_disabled }
  before_update :set_status_changed,
    unless: Proc.new{|i| (!i.status_changed.nil? && !i.will_save_change_to_attribute?('status')) || i.callbacks_disabled }
  before_update :set_missed_record,
    if: Proc.new{|i| i.will_save_change_to_attribute?('status') && i.status == 'missed' && !i.callbacks_disabled }
  after_commit :send_status_change_notifications,
    if: Proc.new{|i| i.saved_change_to_attribute_within_transaction?('status') && !i.callbacks_disabled }
    
  scope :internal, -> { where(external: false) }
  scope :external, -> { where(external: true) }

  enum status: {
    quoted:             0,    # belongs to a not-yet accepted quote
    upcoming:           1,    # not yet payable or due
    available:          2,    # payable
    pending:            3,    # ACH payment submitted but not yet received
    complete:           4,    # payment complete
    missed:             5,    # payment missed
    cancelled:          6,    # cancelled, no longer applies
    managed_externally: 7     # managed by a partner who does not keep us abreast of invoice status
  }

  def with_payment_lock
    ActiveRecord::Base.transaction(requires_new: true) do
      self.lock!
      yield(self.line_items.priced_in.order(id: :asc).lock.to_a)
    end
  end
  
  # for use in views for the user; hides hidden fee/tax line items as premium amounts
  def sanitized_line_items
    lis = self.line_items.to_a
    hidden = lis.select{|li| li.hidden }
    return lis if hidden.blank?
    lis -= hidden
    hidden = hidden.map do |h|
      [
        h,
        lis.select{|li| li.policy_quote_id == h.policy_quote_id || li.policy_id == h.policy_id }
           .map{|li| [li.hidden_substitute_suitability_rating, li] }.select{|x| !x[0].nil? }.sort_by{|x| x[0] }.first&.[](1)
      ]
    end.to_h.transform_values{|sub| sub.nil? ? nil : lis.find_index(sub) }
    subbed = []
    hidden.each do |h,subi|
      if subi.nil?
        # there isn't a suitable line item to add it to, so just obfuscate its nature
        lis.push(h.dup)
        lis.last.title = "Premium"
        lis.last.analytics_category = "policy_premium"
      else
        # replace li with duplicate
        unless subbed.include?(subi)
          subbed.push(subi)
          lis[subi] = lis[subi].dup
        end
        # update duplicate
        [:original_total_due, :total_due, :total_reducing, :total_received, :preproration_total_due, :duplicatable_reduction_total].each do |prop|
          lis[subi].send("#{prop.to_s}=", lis[subi].send(prop) + h.send(prop))
        end
      end
    end
    return lis
  end


  def pay(
    amount: nil,                        # pass a specific integer amount to make a partial payment, default is total_payable
    stripe_source: nil,                 # stripe source id string or token, or :default to use customer's default payment method
    allow_upcoming: false,              # pass true if forcing an otherwise-disallowed payment on an upcoming invoice
    allow_missed: false                 # pass true if forcing an otherwise-disallowed payment on a missed invoice
  )
    # flee if external
    return {
      success: false,
      charge_id: nil,
      charge_status: nil,
      error: "This invoice is external (i.e. only a record of an invoice handled by an external partner system)."
    } if self.external
    # begin lock
    notification_status = nil
    charge_to_distribute = nil
    posttransaction_return = nil
    self.with_lock do
      ActiveRecord::Base.transaction(requires_new: true) do # ensure that rollbacks really roll back
        # set invoice status to processing
        unless self.status == 'available' || (allow_upcoming && self.status == 'upcoming') || (allow_missed && self.status == 'missed')
          return {
            success: false,
            charge_id: nil,
            charge_status: nil,
            error: "This invoice is not eligible for payment, because its billing status is '#{self.status}'."
          }
        end
        # grab the default payment method, if needed
        stripe_source = self.payer.payment_profiles.where(default: true).take&.source_id if stripe_source == :default
        # calculate payment amount
        to_pay = self.total_payable
        if to_pay < 0 || (amount && amount < 0)
          return {
            success: false,
            charge_id: nil,
            charge_status: nil,
            error: "Cannot charge for a negative amount."
          }
        end
        unless amount.nil?
          if amount > to_pay
            return {
              success: false,
              charge_id: nil,
              charge_status: nil,
              error: "Cannot pay more than due."
            }
          end
          to_pay = amount
        end
        # get customer stripe id
        customer_stripe_id = if self.payer.nil? || !self.payer.respond_to?(:stripe_id)
          nil
        else
          self.payer.set_stripe_id if self.payer.stripe_id.nil? && self.payer.respond_to?(:set_stripe_id)
          self.payer.stripe_id
        end
        # update our financial totals for charge creation
        unless self.update(
          pending_charge_count: self.pending_charge_count + 1,
          total_pending: self.total_pending + to_pay,
          total_payable: self.total_payable - to_pay
        )
          return {
            success: false,
            charge_id: nil,
            charge_status: nil,
            error: "Failed to update invoice totals; errors #{self.errors.to_h}."
          }
        end
        # create the charge
        descriptor = get_descriptor # silly ruby can't call private methods with self. :(
        created_charge = ::StripeCharge.create(
          invoice: self,
          amount: to_pay,
          source: stripe_source,
          customer_stripe_id: customer_stripe_id,
          description: descriptor[:description],
          metadata: descriptor[:metadata]
        )
        unless created_charge.id
          posttransaction_return = {
            success: false,
            charge_id: nil,
            charge_status: nil,
            error: "Failed to create charge; errors #{created_charge.errors.to_h}"
          }
          raise ActiveRecord::Rollback
        end
        posttransaction_return = {
          success: true,
          charge: created_charge
        }
      end # end inner transaction
    end # end lock
    if posttransaction_return.nil?
      posttransaction_return = {
        success: false,
        charge_id: nil,
        charge_status: nil,
        error: "Unknown error; charge transaction exited without returning a value"
      }
    elsif posttransaction_return[:success]
      charge = posttransaction_return[:charge].reload # reload, since attempt_payment is triggered by an after_commit callback
      case charge.status
        when 'succeeded', 'pending'
          posttransaction_return = {
            success: true,
            charge_id: charge.id,
            charge_status: charge.status,
            error: nil
          }
        else
          posttransaction_return = {
            success: false,
            charge_id: charge.id,
            charge_status: charge.status,
            error: charge.error_info
          }
      end
    end
    return posttransaction_return
  end
  
  def process_external_charge(charge)
    return if charge.processed
    case charge.status
      when 'pending'
        return if charge.invoice_aware
        self.with_lock do
          ActiveRecord::Base.transaction(requires_new: true) do
            raise ActiveRecord::Rollback unless self.update(
              pending_charge_count: self.pending_charge_count + 1,
              total_pending: self.total_pending + charge.amount,
              total_payable: self.total_payable - charge.amount
            )
            raise ActiveRecord::Rollback unless charge.update(invoice_aware: true)
          end
        end
      when 'failed'
        self.with_lock do
          ActiveRecord::Base.transaction(requires_new: true) do
            raise ActiveRecord::Rollback unless !charge.invoice_aware || self.update(
              pending_charge_count: self.pending_charge_count - 1,
              total_pending: self.total_pending - charge.amount,
              total_payable: self.total_payable + charge.amount
            )
            raise ActiveRecord::Rollback unless charge.update(invoice_aware: true, processed: true)
          end
        end
      when 'succeeded'
        self.with_payment_lock do |line_item_array|
          # peform distribution of the total over our line items
          amount_left = distribute_payment(charge.amount, charge, line_item_array)
          # update ourselves
          raise ActiveRecord::Rollback unless self.update(
            {
              total_received: self.total_received + charge.amount,
              total_undistributable: amount_left
            }.merge(charge.invoice_aware ? {
              pending_charge_count: self.pending_charge_count - 1,
              total_pending: self.total_pending - charge.amount
            } : {
              total_payable: self.total_payable - charge.amount
            })
          )
          # update the charge
          raise ActiveRecord::Rollback unless charge.update(invoice_aware: true, processed: true)
        end
    end
  end
  
  def process_stripe_charge(charge)
    return if charge.processed
    rolled_back = false
    # perform charge processing
    if charge.status == 'processing' && !charge.invoice_aware
      # the first time, we just mark that we've seen it; the HandleUnresponsiveChargesJob will find it if it stays 'processing', try payment again, and send it back to us if it doesn't change
      rolled_back = charge.update(invoice_aware: true) ? false : true
    elsif charge.status == 'succeeded'
      self.with_payment_lock do |line_item_array|
        rolled_back = true
        raise ActiveRecord::Rollback unless charge.update(invoice_aware: true, processed: true)
        # peform distribution of the total over our line items
        amount_left = distribute_payment(charge.amount, charge, line_item_array)
        # update ourselves
        raise ActiveRecord::Rollback unless self.update(
          pending_charge_count: self.pending_charge_count - 1,
          total_pending: self.total_pending - charge.amount,
          total_received: self.total_received + charge.amount,
          total_undistributable: amount_left
        )
        rolled_back = false
      end
    else
      rolled_back = true
      self.with_lock do
        ActiveRecord::Base.transaction(requires_new: true) do # ensure that rollbacks really roll back
          case charge.status
            when 'processing'
              raise ActiveRecord::Rollback unless charge.update(
                status: 'errored',
                invoice_aware: true,
                error_info: "Charge somehow became stuck with status 'processing'.",
                client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
              )
              raise ActiveRecord::Rollback unless self.update(
                under_review: true,
                error_info: (self.error_info || []) + [{
                  description: "Charge attempt resulted in 'processing' charge. This should not occur; somehow the charge never received a valid status and was picked up by the HandleUnresponsiveCharges job.",
                  charge_type: 'StripeCharge',
                  charge_id: charge.id,
                  time: Time.current.to_s,
                  amount: charge.amount
                }]
              )
            when 'errored'
              raise ActiveRecord::Rollback unless charge.update(invoice_aware: true)
              raise ActiveRecord::Rollback unless self.update(
                under_review: true,
                error_info: (self.error_info || []) + [{
                  description: "Charge attempt resulted in 'errored' charge. This means the charge attempt threw no errors and had no failure status, but the returned Stripe object was invalid.",
                  charge_type: 'StripeCharge',
                  charge_id: charge.id,
                  time: Time.current.to_s,
                  amount: charge.amount
                }]
              )
            when 'failed'
              raise ActiveRecord::Rollback unless charge.update(invoice_aware: true, processed: true)
              raise ActiveRecord::Rollback unless self.update(
                pending_charge_count: self.pending_charge_count - 1,
                total_pending: self.total_pending - charge.amount,
                total_payable: self.total_payable + charge.amount
              )
          end # end case
          rolled_back = false
        end # end transaction
      end # end lock
    end # end if
    # handle notifications
    unless rolled_back
      self.send_charge_notifications(charge)
      self.process_reductions
    end
  end
  
  def process_reductions
    return "Failure: awaiting resolution of pending charges" if self.pending_charge_count > 0
    return "Failure: awaiting resolution fo pending disputes" if self.pending_dispute_count > 0
    error_message = "Success"
    self.with_payment_lock do |line_item_array|
      return "Failure: awaiting resolution of pending charges" if self.pending_charge_count > 0
      return "Failure: awaiting resolution fo pending disputes" if self.pending_dispute_count > 0
      lirs = self.line_item_reductions.pending.order(refundability: :desc, created_at: :asc).group_by{|lir| lir.line_item }
      return "Success: no LIRs exist for this invoice" if lirs.blank?
      refund_object = nil
      # handle reductions
      total_due_change = 0
      total_received_change = 0
      total_to_refund = 0
      line_item_array.each do |li|
        lilirs = lirs[li] || []
        next if lilirs.blank? && li.total_reducing == 0
        li.total_due += li.total_reducing
        li.total_reducing = 0
        lilirs.each do |lir|
          # calculate change to total_due
          to_reduce = lir.get_amount_to_reduce(li)
          li.total_due -= to_reduce
          case lir.proration_interaction
            when 'duplicated';  li.duplicatable_reduction_total += to_reduce
            when 'reduced';     li.preproration_total_due -= to_reduce
          end
          lir.amount_successful += to_reduce
          newborn = li.line_item_changes.create(field_changed: 'total_due', amount: -to_reduce, reason: lir, new_value: li.total_due)
          unless to_reduce == 0 || !newborn.id.nil?
            error_message = "Failure: error while creating LIC (total_due for LI #{li.id} and LIR #{lir.id}): #{newborn.errors.to_h}"
            raise ActiveRecord::Rollback
          end
          total_due_change -= to_reduce
          # calculate change to total_received
          to_unpay = (lir.refundability == 'cancel_only' ? 0 : [to_reduce, li.total_received - li.total_due].min)
          unless to_unpay <= 0
            # li
            li.total_received -= to_unpay
            total_received_change -= to_unpay
            # lic
            newborn = li.line_item_changes.create(field_changed: 'total_received', amount: -to_unpay, reason: lir, new_value: li.total_received)
            unless to_unpay == 0 || !newborn.id.nil?
              error_message = "Failure: error while creating LIC (total_received for LI #{li.id} and LIR #{lir.id}): #{newborn.errors.to_h}"
              raise ActiveRecord::Rollback
            end
            # lir
            refund_object ||= ::Refund.create(invoice: self)
            if refund_object.id.nil?
              error_message = "Failure: error while creating Refund: #{refund_object.errors.to_h}"
              raise ActiveRecord::Rollback
            end
            lir.refund = refund_object
            lir.amount_refunded += to_unpay
            total_to_refund -= to_unpay
          end
          # the LIR has now been handled
          lir.pending = false
          unless lir.save
            error_message = "Failure: error while saving LIR #{lir.id} (for LI #{li.id}): #{lir.errors.to_h}"
            raise ActiveRecord::Rollback
          end
        end
        unless li.save
          error_message = "Failure: error while saving LI #{li.id}: #{li.errors.to_h}"
          raise ActiveRecord::Rollback
        end
      end
      unless self.update(
        total_due: self.total_due + self.total_reducing + total_due_change,
        total_payable: [self.total_due + self.total_reducing + total_due_change - (self.total_received + total_received_change), 0].max,
        total_reducing: 0,
        total_received: self.total_received + total_received_change
      )
        error_message = "Failure: error while updating invoice totals: #{self.errors.to_h}"
        raise ActiveRecord::Rollback 
      end
      # create refund
      unless refund_object.nil?
        refund_error_message = refund_object.execute
        unless refund_error_message.nil?
          error_message = "Failure: error while executing refund: #{refund_error_message}"
          raise ActiveRecord::Rollback
        end
      end
    end # end payment_lock
    return error_message
  end

  # WARNING: only called from stripe charges right now, not external charges!
  def send_charge_notifications(charge)
    case charge.status # value will never be 'processing'
      when 'errored'
      when 'pending'
      when 'failed'
      when 'succeeded'
    end
  end
  
  def send_status_change_notifications
    # inform the invoiceable, if relevant
    case self.status
      when 'quoted', 'managed_externally'
        return nil # do nothing
      when 'upcoming', 'pending'
        return nil # do nothing
      when 'available'
        self.invoiceable.invoice_available(self) if self.invoiceable.respond_to?(:invoice_available)
      when 'complete'
        self.invoiceable.invoice_complete(self) if self.invoiceable.respond_to?(:invoice_complete)
      when 'missed'
        self.invoiceable.invoice_missed(self) if self.invoiceable.respond_to?(:invoice_missed)
      when 'cancelled'
        self.invoiceable.invoice_cancelled(self) if self.invoiceable.respond_to?(:invoice_cancelled)
    end
    # send any other notifications
    if self.autosend_status_change_notifications
      # this gets called after_commit whenever our status has changed
      # MOOSE WARNING: fill this out, notification people
    end
  end
  
  def get_proper_status
    if self.total_received >= self.total_due
      return 'complete'
    elsif self.total_received + self.total_pending >= self.total_due
      return 'pending'
    else
      nowtime = Time.current.to_date
      if nowtime > self.due_date
        return self.total_pending > 0 ? 'pending' : 'missed'
      elsif nowtime < self.available_date
        return 'upcoming'
      end
    end
    return 'available'
  end


  private
  
    # set invoice number
    def set_number
      loop do
        self.number = rand(36**12).to_s(36).upcase
        break unless ::Invoice.exists?(number: number)
      end
    end
  
    # bring in line items
    def mark_line_items_priced_in
      dat_total_tho = 0
      self.line_items.group_by{|li| li.id.nil? }.each do |unsaved, lis|
        if unsaved
          lis.each{|li| li.priced_in = true; dat_total_tho += li.total_due }
        else
          ::LineItem.where(id: lis.map{|li| li.id }).update_all(priced_in: true)
          lis.each{|li| dat_total_tho += li.total_due }
        end
      end
      self.original_total_due = dat_total_tho
      self.total_due = dat_total_tho
      self.total_payable = dat_total_tho
    end
  
    # sets our current status based on various values
    def set_status
      unless self.external || self.status == 'quoted' || self.status == 'cancelled' || self.status == 'managed_externally'
        self.status = self.get_proper_status
      end
    end
    
    # set our status changed time
    def set_status_changed
      self.status_changed = Time.current
    end
    
    # set missed record data when status is about to update to missed
    def set_missed_record
      self.was_missed = true
      self.was_missed_at ||= Time.current
    end

    # returns a descriptor for charges to send to stripe, format { description: string, metadata: hash_of_metadata_entries }
    def get_descriptor(to_describe = self.invoiceable)
      description = "GetCovered Product"
      metadata = { product_type: to_describe.class.name, product_id: to_describe.respond_to?(:id) ? to_describe.id : 'N/A', metadata_version: 1 }
      case to_describe
        when ::Policy
          description = "#{to_describe.policy_type.title}#{to_describe.policy_type.title.end_with?("Policy") || to_describe.policy_type.title.end_with?("Coverage") ? "" : " Policy"} ##{to_describe.number}"
          metadata[:product] = to_describe.policy_type.title
          metadata[:agency] = to_describe.agency&.title
          metadata[:account] = to_describe.account&.title
          metadata[:policy_number] = to_describe.number
          metadata[:carrier] = to_describe.carrier&.title
        when ::PolicyQuote
          to_describe.policy.nil? ? "Policy Quote ##{to_describe.reference}" : get_descriptor(to_describe.policy)
          if to_describe.policy.nil?
            description = "Policy Quote ##{to_describe.reference}"
            metadata[:product] = to_describe.policy_application&.policy_type&.title || "Policy"
            metadata[:agency] = to_describe.agency&.title
            metadata[:account] = to_describe.account&.title
            metadata[:policy_quote_reference] = to_describe.reference
          else
            return get_descriptor(to_describe.policy)
          end
        when ::PolicyGroup
          description = "#{to_describe.policy_type.title}#{to_describe.policy_type.title.end_with?("Policy") || to_describe.policy_type.title.end_with?("Coverage") ? "" : " Policy"} ##{to_describe.number}"
          metadata[:product] = to_describe.policy_type.title
          metadata[:agency] = to_describe.agency&.title
          metadata[:account] = to_describe.account&.title
          metadata[:policy_group_number] = to_describe.number
          metadata[:carrier] = to_describe.carrier&.title
        when ::PolicyGroupQuote
          if to_describe.policy_group.nil?
            description = "Policy Group Quote ##{to_describe.reference}"
            metadata[:product] = to_describe.policy_application_group&.policy_type&.title || "Policy"
            metadata[:agency] = to_describe.agency&.title
            metadata[:account] = to_describe.account&.title
            metadata[:policy_group_quote_reference] = to_describe.reference
          else
            return get_descriptor(to_describe.policy_group)
          end
        else
          # do nothing
      end
      return {
        description: "#{description}, Invoice ##{self.number}",
        metadata: metadata.merge(get_payer_metadata).merge({ invoice_id: self.id, invoice_number: self.number })
      }
    end
    
    def get_payer_metadata
      to_return = {
        payer_type: payer.class.name,
        payer_id: payer.respond_to?(:id) ? payer.id : 'N/A'
      }
      case payer
        when ::User
          to_return[:payer_first_name] = payer.profile&.first_name
          to_return[:payer_last_name] = payer.profile&.last_name
          to_return[:payer_phone] = payer.profile&.contact_phone
        when ::Account
          to_return[:payer_company_name] = payer.title
        when ::Agency
          to_return[:payer_company_name] = payer.title
        else
          # do nothing
      end
      return to_return
    end
    
    
    # distributes a payment over line items
    # WARNING: to be called from within a with_payment_lock transaction!
    # Rolls back on failure!
    def distribute_payment(amount, reason, line_item_array)
      line_item_array.sort!
      amount_left = amount
      if amount_left > 0
        line_item_array.select{|li| li.total_due + li.total_reducing > li.total_received }.each do |li|
          clamped_amount = [li.total_due + li.total_reducing - li.total_received, amount_left].min
          if clamped_amount == 0
            break if amount_left == 0
            next
          end
          created = li.line_item_changes.create(field_changed: 'total_received', amount: clamped_amount, reason: reason, new_value: li.total_received + clamped_amount)
          raise ActiveRecord::Rollback unless !created.id.nil? && li.update(total_received: li.total_received + clamped_amount)
          amount_left -= clamped_amount
        end
      end
      return amount_left
    end


end
