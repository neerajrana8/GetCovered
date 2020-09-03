# frozen_string_literal: true

# Invoice model
# file: app/models/invoice.rb

class Invoice < ApplicationRecord
  # ActiveRecord Callbacks

  include ElasticsearchSearchable

  before_validation :calculate_subtotal,
    on: :create
    
  before_validation :calculate_total

  before_validation :set_number, on: :create

  before_save :set_status_changed, if: -> { status_changed? }
  
  before_save :set_was_missed, if: Proc.new{|inv| inv.will_save_change_to_attribute?('status') && inv.status == 'missed' }
  
  before_create :mark_line_items_priced_in

  after_save :total_collected_changed, if: Proc.new{|inv| inv.status == 'complete' && (inv.saved_change_to_attribute?('amount_refunded') || inv.saved_change_to_attribute?('status')) }

  # ActiveRecord Associations

  belongs_to :invoiceable, polymorphic: true
  belongs_to :payer, polymorphic: true
  
  has_many :charges
  has_many :refunds, through: :charges
  has_many :disputes, through: :charges
  has_many :line_items, autosave: true
  
  has_many :histories, as: :recordable
  #has_many :notifications, as: :eventable

  scope :internal, -> { where(external: false) }
  scope :external, -> { where(external: true) }

  # Validations

  validates :number, presence: true, uniqueness: true
  validates :subtotal, presence: true
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :due_date, presence: true
  validates :available_date, presence: true
  
  validates_associated :line_items
  validate :term_dates_are_sensible

  accepts_nested_attributes_for :line_items

  # Enums

  enum status: %w[quoted upcoming available processing complete missed canceled]

  scope :paid, -> { where(status: %w[complete]) }
  scope :unpaid, -> { where(status: %w[available missed]) }
  scope :unpaid_past_due, -> { 
    where(status: %w[available missed]).where('due_date < ?', DateTime.now)
  }

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :number, type: :text
    end
  end
  # Methods


  # refresh price for new line items
  def refresh
    with_lock do
      if status == 'available' || status == 'upcoming' || status == 'missed'
        self.subtotal = line_items.inject(0) { |result, line_item| result += line_item.price }
        self.total = self.subtotal - self.proration_reduction
        self.save!
        self.line_items.update_all(priced_in: true)
      end
    end
  end

  def refresh_totals
    self.subtotal = line_items.inject(0) { |result, line_item| result += line_item.price }
    self.total = self.subtotal - self.proration_reduction
    self.save!
    self.line_items.update_all(priced_in: true)
  end

  # Apply Proration
  #
  # Apply a proration to the invoice. If the new_term_last_date falls
  # before this invoice's term, the invoice will be canceled or totally refunded;
  # if it falls after, nothing will happen; if it falls within, a refund
  # will be issued or the total adjusted in proportion to the part of the term
  # before (and including) new_term_last_date, and term_last_date will be set
  # equal to new_term_last_date.
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   proration_date = Time.current.to_date - 2.weeks
  #   @invoice.apply_proration(proration_date)
  #   => true
  

  # params:
  #   new_term_last_date:         the term end date to be used in calculating the proration (the last day of the term, not the first day of not-the-term)
  #   refund_date:                the date the refund is initiated, used to calculate whether to refund 'complete_refund_before_term', etc. refundability line items;
  #                               defaults to Time.current.to_date
  #   to_refund_override:         an array of { 'line_item' => line_item (or line_item id), 'amount' => number of cents to ensure have been refunded } hashes;
  #                               defaults to a hash created based on the other parameters which prorates the invoice
  #   to_ensure_refunded:         same as to_refund_override in format; if non-nil, after the to_refund hash has been calculated (or provided by to_refund_override),
  #                               any line items missing/with a lower refund than specified by to_ensure_refunded will be added/have their refund increased to match to_ensure_refunded;
  #                               can also pass a proc that takes a LineItem (and optionally the invoice as its second argument) and returns the amount to ensure is refunded
  #   cancel_if_unpaid_override:  true to completely cancel the invoice, rather than only applying the proration, if it is upcoming/available;
  #                               false to apply the proration as normal;
  #                               defaults to (new_term_last_date < term_first_date)
  #   cancel_if_missed_override:  true to completely cancel the invoice, rather than only applying the proration, if it is missed;
  #                               false to apply the proration as normal;
  #                               defaults to cancel_if_unpaid_override, if provided, or to its default value if not
  def apply_proration(new_term_last_date, refund_date: nil, to_refund_override: nil, to_ensure_refunded: nil, cancel_if_unpaid_override: nil, cancel_if_missed_override: nil)
    with_lock do
      return false if term_first_date.nil? || term_last_date.nil?
      to_refund = nil
      cancel_if_unpaid = false
      # calculate the to_refund hash
      if to_refund_override.nil?
        # get refund date and proportion-to-refund
        refund_date = Time.current.to_date if refund_date.nil?
        proportion_to_refund = 0
        proportion_to_refund = new_term_last_date < term_first_date ? 1.to_d :
                               new_term_last_date >= term_last_date ? 0.to_d :
                               (term_last_date - new_term_last_date).to_i.to_d / ((term_last_date - term_first_date) + 1).to_i.to_d
        # set cancel_if_unpaid
        cancel_if_unpaid = (new_term_last_date < term_first_date)
        # calculate how much to refund
        to_refund = line_items.map do |li|
          {
            'line_item' => li,
            'amount' => case li.refundability
              when 'no_refund'
                (li.full_refund_before_date.nil? || li.full_refund_before_date < refund_date) ?
                  li.price
                  : 0
              when 'prorated_refund'
                (li.full_refund_before_date.nil? || li.full_refund_before_date < refund_date) ?
                  li.price
                  : (li.price * proportion_to_refund).floor
              else
                0
            end
          }
        end.select{|datum| datum['amount'] > 0 }
      else
        # copy over to to_refund and sanitize line items (in case the user passed ids)
        to_refund = to_refund_override
        to_refund.each do |li|
          li['line_item'] = line_items.find{|lim| lim.id == li['line_item'] } if li['line_item'].class != ::LineItem
          return false if li['line_item'].nil?
        end
      end
      # add to_ensure_refunded to the to_refund hash
      unless to_ensure_refunded.nil?
        if to_ensure_refunded.class == ::Proc
          # expand proc
          to_ensure_refunded = line_items.map{|li| { 'line_item' => li, 'amount' => to_ensure_refunded.call(li, self) } }.select{|li| li['amount'] && li['amount'] > 0 }
        else
          # sanitize line items (in case the user passed ids)
          to_ensure_refunded.each do |li|
            li['line_item'] = line_items.find{|lim| lim.id == li['line_item'] } if li['line_item'].class != ::LineItem
            return false if li['line_item'].nil?
          end
        end
        # merge into to_refund
        to_ensure_refunded.each do |li|
          found = to_refund.find{|trli| trli['line_item'].id == li['line_item'].id }
          if found.nil?
            to_refund.push({ 'line_item' => li, 'amount' => li['amount'] })
          elsif found['amount'] < li['amount']
            found['amount'] = li['amount']
          end
        end
      end
      # set cancel_if settings
      cancel_if_unpaid = cancel_if_unpaid_override unless cancel_if_unpaid_override.nil?
      cancel_if_missed = cancel_if_missed_override.nil? ? cancel_if_unpaid : cancel_if_missed_override
      # apply refund
      case status == 'missed' ? ("missed_#{cancel_if_missed ? 'cancel' : 'keep'}") : status
        when 'complete'
          # apply the refund
          return true if to_refund.blank?
          result = ensure_refunded(to_refund, "Proration Adjustment", nil)
          return true if result[:success]
          return false # WARNING: we discard result[:errors] here
        when 'upcoming', 'available', 'missed_keep' # WARNING: for missed-and-not-to-be-canceled invoices here we lose information on the original missed amount, retaining only what is actually due now
          # apply a proration adjustment
          prored = to_refund.inject(0){|sum,li| sum + li['amount'] }
          if prored > subtotal
            self.reduce_distribution_total(subtotal, :adjustment, to_refund)
            prored = subtotal
          end
          to_refund.each do |li|
            li['line_item'].update(proration_reduction: li['amount'])
          end
          return update({ proration_reduction: prored, total: subtotal - prored }.merge(
            (cancel_if_unpaid && status != 'missed') ? { status: 'canceled' } : {}
          ))
        when 'processing', 'canceled', 'missed_cancel'
          return update({
            has_pending_refund: true,
            pending_refund_data: {
              'proration_refund' => to_refund.map{|li| {
                'line_item' => li['line_item'].id,
                'amount' => li['amount']
              } },
              'cancel_if_unpaid' => cancel_if_unpaid,
              'cancel_if_missed' => cancel_if_missed
            }
          }.merge(status == 'missed' ? { status: 'canceled' } : {}))
      end
    end
    return false
  end
  

  # refunds whatever is necessary to ensure the total amount refunded is to_refund cents (if it starts above that, it refunds nothing)
  def ensure_refunded(to_refund, full_reason = nil, stripe_reason = nil, ignore_total: false)
    with_lock do
      return { success: false, errors: "invoice status must be 'complete' before refunding" } unless status == 'complete'
      # get line item breakdown if provided a scalar number
      to_refund = [to_refund] if to_refund.class == ::Hash
      unless to_refund.class == ::Array
        to_refund = get_fund_distribution(to_refund, :max_refund, leave_line_item_models: true)
      end
      # validate line item breakdown
      begin
        to_refund.each do |li|
          li['line_item'] = self.line_items.where(id: li['line_item']).take unless li['line_item'].class == ::LineItem
          return { success: false, errors: "invalid line items specified" } if li['line_item'].nil?
        end
      rescue
        return { success: false, errors: "invalid line items specified" }
      end
      # flee if there's excess
      unless ignore_total
        return { success: true } if to_refund.inject(0){|sum,li| sum + li['amount'] } <= self.reload.amount_refunded
      end
      # fix line item breakdown to actually refundable amounts
      to_refund.each do |li|
        li['amount'] = [li['amount'] - (li['line_item'].price - li['line_item'].collected), 0].max # remove whatever was previously refunded of that line item
        li['amount'] = [li['amount'], li['line_item'].collected].min
      end
      to_refund = to_refund.select{|li| li['amount'] > 0 }
      # apply refund
      return { success: true } if to_refund.blank?
      return apply_refund(to_refund, full_reason, stripe_reason)
    end
  end
  
  # refunds an exact amount, regardless of what has been refunded before; or refunds as much of it as possible and reports what it failed to refund
  def apply_refund(to_refund, full_reason = nil, stripe_reason = nil)
    errors_encountered = {}
    with_lock do
      return { success: false, errors: "invoice status must be 'complete' before refunding" } unless status == 'complete'
      # get line item breakdown if provided a scalar number
      to_refund = [to_refund] if to_refund.class == ::Hash
      unless to_refund.class == ::Array
        to_refund = get_fund_distribution(to_refund, :refund, leave_line_item_models: true)
      end
      # validate line item breakdown
      begin
        to_refund.each do |li|
          li['line_item'] = self.line_items.where(id: li['line_item']).take unless li['line_item'].class == ::LineItem
          return { success: false, errors: "invalid line items specified" } if li['line_item'].nil?
          return { success: false, errors: "refund amount #{li['amount']} for line item #{li['line_item'].title} cannot exceed amount collected (#{li['amount']})" } if li['amount'] > li['line_item'].collected
        end
      rescue
        return { success: false, errors: "invalid line items specified" }
      end
      # apply refunds
      left_to_refund = to_refund.inject(0){|sum,li| sum + li['amount'] }
      total_to_refund = left_to_refund
      charges.succeeded.each do |current_charge|
        to_refund_now = [[current_charge.amount - current_charge.amount_refunded, left_to_refund].min, 0].max
        result = current_charge.apply_refund(to_refund_now, full_reason, stripe_reason)
        if result[:success]
          left_to_refund -= to_refund_now
          break if left_to_refund <= 0
        else
          errors_encountered[current_charge.id] = result[:errors]
        end
      end
      # apply line item changes (just in case errors prevented the full refund)
      self.reduce_distribution_total(total_to_refund - left_to_refund, :refund, to_refund) if left_to_refund > 0
      to_refund.each do |li|
        li['line_item'].update(collected: li['line_item'].collected - li['amount'])
      end
      self.update(amount_refunded: self.amount_refunded + total_to_refund - left_to_refund)
      {
        success: left_to_refund <= 0,
        amount_not_refunded: left_to_refund,
        errors: {},
        errors_by_charge: errors_encountered,
        by_line_item: to_refund
      }
    end
  end


  # Pay
  #
  # Build charge and sync to stripe
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   @invoice.pay()
  #   => { success: true }

  def pay(allow_upcoming: false, allow_missed: false, stripe_source: nil, stripe_token: nil) # all optional... stripe_source can be passed as :default instead of a source id string to use the default payment method
    # set invoice status to processing
    return_error = nil
    with_lock do
      unless (status == 'available' || (allow_upcoming && status == 'upcoming') || (allow_missed && status == 'missed')) && update(status: 'processing')
        return_error = {
          success: false,
          charge_id: nil,
          charge_status: nil,
          error: status == 'processing' ? 'A payment is already being processed for this invoice'
                                        : "This invoice is not eligible for payment, because its billing status is #{status}"
        }
      end
    end
    return return_error unless return_error.nil?
    # grab the default payment method, if needed
    stripe_source = payer.payment_profiles.where(default: true).take&.source_id if stripe_source == :default
    # attempt to make payment
    created_charge = nil
    created_charge = if !stripe_source.nil?    # use specified source
                       charges.create(amount: total, stripe_id: stripe_source)
                     elsif !stripe_token.nil?  # use token
                       charges.create(amount: total, stripe_id: stripe_token)
                     else                      # use charge's default behavior (which right now this is to succeed if the amount is 0, else to fail with an error message)
                       charges.create(amount: total)
                     end

    # return (callbacks from charge creation will have set our status so that it is no longer 'processing')
    if created_charge.nil?
      return({ success: false, error: 'Failed to create charge', charge_id: nil, charge_status: nil })
    elsif created_charge.status == 'processing'
      return({ success: false, error: 'Failed to sync charge to payment processor', charge_id: created_charge.id, charge_status: 'processing' })
    elsif created_charge.status == 'pending'
      return({ success: true, charge_id: created_charge.id, charge_status: 'pending' })
    elsif created_charge.status == 'succeeded'
      return({ success: true, charge_id: created_charge.id, charge_status: 'succeeded' })
    elsif created_charge.status == 'failed'
      return({ success: false, error: created_charge.status_information, charge_id: created_charge.id, charge_status: 'failed' })
    end

    # this should never be run, but just in case
    { success: false, error: 'Unknown error', charge_id: created_charge.nil? ? nil : created_charge.id, charge_status: created_charge.nil? ? nil : created_charge.status }
  end

  def payment_succeeded(charge)
    with_lock do
      if self.status == 'processing'
        # update our status and distribute funds over line items
        dist = get_fund_distribution(charge.amount, :payment, leave_line_item_models: true)
        dist.each do |line_item_payment|
          line_item_payment['line_item'].update!(collected: line_item_payment['line_item'].collected + line_item_payment['amount'])
        end
        self.update!(status: 'complete')
        # invoiceable callback
        invoiceable.payment_succeeded(self) if invoiceable.respond_to?(:payment_succeeded)
        # handle pending proration refund if we have one
        if has_pending_refund && pending_refund_data.has_key?('proration_refund')
          if apply_proration(nil, to_refund_override: pending_refund_data['proration_refund'], cancel_if_unpaid_override: pending_refund_data['cancel_if_unpaid'], cancel_if_missed_override: pending_refund_data['cancel_if_missed'])
            update_columns(has_pending_refund: false)
          else
            # WARNING: do nothing on proration application failure... would be a good place for a generalized error to be logged to the db
          end
        end
      end
    end
  end

  def payment_failed(charge)
    with_lock do
      if self.status == 'processing'
        invoiceable.payment_failed(self) if invoiceable.respond_to?(:payment_failed)
        if due_date >= Time.current.to_date
          self.update!(status: 'available')
        else
          self.payment_missed
        end
      end
    end
  end
  
  def payment_missed(unless_processing: false)
    with_lock do
      if self.status == 'available' || (!unless_processing && self.status == 'processing') # other statuses mean we were canceled or already paid
        self.update!(status: 'missed')
        if self.has_pending_refund && self.pending_refund_data.has_key?('proration_refund')
          if apply_proration(nil, to_refund_override: pending_refund_data['proration_refund'], cancel_if_unpaid_override: pending_refund_data['cancel_if_unpaid'], cancel_if_missed_override: pending_refund_data['cancel_if_missed'])
            update!(has_pending_refund: false)
          else
            # WARNING: do nothing on proration application failure... would be a good place for a generalized error to be logged to the db
          end
        end
        invoiceable.payment_missed(self) if invoiceable.respond_to?(:payment_missed) && self.reload.status != 'canceled' # just in case apply_proration reduced our total due to 0 and we are now canceled instead of missed
      end
    end
  end
  
  # returns a descriptor for charges to send to stripe, format { description: string, metadata: hash_of_metadata_entries }
  def get_descriptor(to_describe = self.invoiceable, extra_metadata: {})
    description = "GetCovered Product"
    metadata = { product_type: to_describe.class.name, product_id: to_describe.respond_to?(:id) ? to_describe.id : 'N/A' }
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
      metadata: metadata.merge(get_payer_metadata).merge({ invoice_id: self.id, invoice_number: self.number }).merge(extra_metadata)
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
  
  # keep track of number of disputed charges
  def modify_disputed_charge_count(count_change)
    return true if count_change == 0
    with_lock do
      # update our dispute count
      new_disputed_charge_count = disputed_charge_count + count_change
      if new_disputed_charge_count < 0
        return false # makra pragmata ei touto gignotai
      end
      update(disputed_charge_count: new_disputed_charge_count)
      if new_disputed_charge_count == 0
        refunds.queued.each{|ref| ref.process(true) }
      end
      # update our invoiceable if it wants updates
      invoice_dispute_changes = (new_disputed_charge_count == count_change ? 1 : new_disputed_charge_count == 0 ? -1 : 0)
      if self.invoiceable.respond_to?(:modify_disputed_invoice_count) && invoice_dispute_changes != 0
        self.invoiceable.modify_disputed_invoice_count(invoice_dispute_changes)
      end
    end
    return true
  end
  
  # whether refunds must start queued instead of running immediately
  def refunds_must_start_queued?
    return(self.reload.disputed_charge_count > 0)
  end

  # returns [ [group of line items paid first], [group of line items paid next], ..., [group of line items paid last] ]
  # filters out line items which don't satisfy the block, if one was provided
  # mode should be:
  #   :payment to order from first to pay to last to pay
  #   :refund to order from first to refund to last to refund
  #   :adjustment & :max_refund are the same as refund, provided for convenient use by get_fund_distribution
  def line_item_groups(mode = :payment, &block)
    self.line_items.select{|li| li.priced_in }.sort.slice_when do |a,b|
      a.refundability != b.refundability || a.full_refund_before_date != b.full_refund_before_date
    end.to_a.send(mode == :payment ? :itself : :reverse)
  end

  # returns an array of { line_item: $line_item_id, amount: $currency_amount } hashes giving a distribution of dist_amount over the line items
  # applies in order: [no_refund, complete_refund_before_term, prorated_refund, complete_refund_during_term], with complete_refund_before_due_date inserted before one of the term date-based ones depending on the due date;
  # applies refunds/adjustments in reverse order;
  # distributes payments proportionally over line items with the same refund type;
  # mode should be:
  #   :payment for payment application
  #   :refund for refund application
  #   :max_refund for refund application without regard to what's already been refunded
  #   :adjustment for determining proration adjustments on unpaid invoices
  def get_fund_distribution(dist_amount, mode, leave_line_item_models: false, &block)
    amt_left = dist_amount
    return(self.line_item_groups(mode, &block).map do |lig|
        # prepare
        amounts = lig.map{|li| {
          line_item: li,      # the line item model this entry applies to
          weight: case mode   # the weight for proportional allocation among line items in the same group
            when :payment; li.adjusted_price
            when :refund, :max_refund, :adjustment; li.price;
          end,
          ceiling: case mode  # the max amount allocatable to this line item
            when :payment; [li.adjusted_price - li.collected, 0].max # shouldn't be < 0, but just in case
            when :refund; li.collected
            when :max_refund; li.price
            when :adjustment; [li.price - li.collected, 0].max # shouldn't be < 0, but just in case
          end,
          amount: 0           # the amount allocated to this line item so far
        } }
        total_ceiling = amounts.inject(0){|sum,amt| sum + amt[:ceiling] }
        total_amt = [amt_left, total_ceiling].min
        # handle easy cases
        if total_amt == 0
          next []
        elsif total_amt > total_ceiling
          amounts.each{|amt| amt[:amount] = amt[:ceiling] }
          amt_left -= total_ceiling
          next amounts
        end
        # distribute
        lig_amt_left = total_amt
        while lig_amt_left > 0
          old_lig_amt_left = lig_amt_left
          # distribute proportionally, never exceeding ceilings
          relevant_amounts = amounts.select{|amt| amt[:amount] < amt[:ceiling] }
          total_weight = relevant_amounts.inject(0){|sum,amt| sum + amt[:weight] }.to_d
          total_weight = 1.to_d if total_weight == 0
          relevant_amounts.each do |amt|
            amt[:amount] += [(lig_amt_left * amt[:weight] / total_weight).floor, amt[:ceiling] - amt[:amount]].min
          end
          lig_amt_left = total_amt - amounts.inject(0){|sum,amt| sum + amt[:amount] }
          # if the floor functions prevented any change, allocate 1 cent to the line item with the greatest proportional difference from its ceiling
          if lig_amt_left == old_lig_amt_left
            to_increment = relevant_amounts.sort do |amt1,amt2|
              (amt1[:ceiling] - amt1[:amount]).to_d / (amt1[:weight] == 0 ? 1 : amt1[:weight]) <=>
              (amt2[:ceiling] - amt2[:amount]).to_d / (amt2[:weight] == 0 ? 1 : amt2[:weight])
            end.last
            to_increment[:amount] += 1
            lig_amt_left -= 1
          end
        end
        # paranoid error-fixing, just in case a negative somehow slips in one day (ignores efficiency considerations and handles things cent-by-cent)
        while lig_amt_left < 0
          amounts.find{|amt| amt[:amount] > 0 }[:amount] -= 1
          lig_amt_left += 1
        end
        # we're done with this line item group
        amt_left -= total_amt
        next amounts
      end.flatten
         .map{|li_entry| {
            'line_item' => leave_line_item_models ? li_entry[:line_item] : li_entry[:line_item].id,
            'amount' => li_entry[:amount]
          } }
         .select{|li_entry| li_entry['amount'] != 0 }
    )
  end

  def apply_dispute_refund(dispute)
    with_lock do
      dist = self.get_fund_distribution(dispute.amount, :refund, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update!(collected: li['line_item'].collected - li['amount'])
      end
      self.update!(amount_refunded: self.amount_refunded + dispute.amount)
    end
  end

  private

    # Calculation Methods

    def calculate_subtotal
      old_subtotal = self.will_save_change_to_attribute?('subtotal') ? self.subtotal : nil
      self.subtotal = line_items.inject(0) { |result, line_item| result += line_item.price }
      errors.add(:subtotal, "must match sum of line item prices") unless old_subtotal.nil? || old_subtotal == self.subtotal
    end

    def calculate_total
      old_total = self.will_save_change_to_attribute?('total') ? self.total : nil
      self.total = self.subtotal - self.proration_reduction # total is subtotal - proration_reduction
      errors.add(:total, "must match subtotal") unless old_total.nil? || old_total == self.total
    end

    def term_dates_are_sensible
      errors.add(:term_last_date, "cannot precede term first date") unless term_last_date.nil? || term_first_date.nil? || (term_last_date >= term_first_date)
      errors.add(:term_last_date, "cannot be blank when term first date is provided") if term_last_date.nil? && !term_first_date.nil?
      errors.add(:term_first_date, "cannot be blank when term last date is provided") if term_first_date.nil? && !term_last_date.nil?
    end

    def mark_line_items_priced_in
      # it's redundant to calculate these twice, but I'm paranoid about validations being missed or called early; better safe than sorry when dealing with money!
      calculate_subtotal
      calculate_total
      if self.errors.blank?
        self.line_items.each{|li| li.priced_in = true } # in case they aren't saved yet
        self.line_items.update_all(priced_in: true) # in case they are saved -_-'
      else
        throw :abort
      end
    end

    # History Methods

    def history_whitelist
      [:status]
    end

    def related_classes_through
      []#[:policy]
    end

    def related_create_hash(_calling_relation)
      {
        self.class.name.to_s.downcase.pluralize => {
          'model' => self.class.name.to_s,
          'id' => id,
          'message' => "New invoice ##{number}"
        }
      }
    end

    def set_number
      loop do
        self.number = rand(36**12).to_s(36).upcase

        break unless Invoice.exists?(number: number)
      end
    end

    def set_status_changed
      self.status_changed = Time.current
    end

    def set_was_missed
      self.was_missed = true
    end


    def reduce_distribution_total(new_total, mode, distribution)
      # WARNING: this shouldn't need to get called, so it just does the simplest thing possible..
      # ideally it would act like get_fund_distribution, using line_item_groups and reducing amounts proportionally in each group in sequence
      old_total = distribution.inject(0){|sum,li| sum + li['amount'] }
      while old_total > new_total
        distribution.find{|d| d['amount'] > 0 }['amount'] -= [d['amount'], old_total - new_total].min
      end
    end


    def total_collected_changed
      # get amounts collected
      amount_collected = self.total - self.amount_refunded
      old_amount_collected = (self.attribute_before_last_save('status') != 'complete' ? 0 : self.total || 0) - (self.attribute_before_last_save('amount_refunded') || 0)
      self.invoiceable.invoice_collected_changed(self, amount_collected, old_amount_collected) if self.invoiceable.respond_to?(:invoice_collected_changed)
    end

    # This method uses deprecated fields (e.g. agency_total).
    # Either refactor it or delete.
    def set_commission
      policy = self.invoiceable_type == 'Policy' ? self.invoiceable : nil
      unless policy.nil?
        agency_commission_rate = policy.agency.carrier_commission(policy.carrier.id)
        account_commission_rate = policy.account.commission_rate

        house_agency = policy.agency.master_agency?

        self.agency_subtotal = (subtotal * "0.#{agency_commission_rate}".to_f).ceil
        self.carrier_total = subtotal - agency_subtotal
        self.account_total = (agency_subtotal.to_f * "0.#{account_commission_rate}".to_f).ceil
        self.house_subtotal = (agency_subtotal * "0.#{policy.agency.master_commission_split}".to_f).ceil

        service_split = {}
        service_split[:difference] = (total - subtotal)
        service_split[:agency] = service_split[:difference] > 0 ? (service_split[:difference] * "0.#{policy.agency.master_take_split}".to_f).ceil : 0
        service_split[:house] = service_split[:difference] - service_split[:agency]

        self.house_total = house_agency ? (agency_subtotal - account_total) + service_split[:house] : house_subtotal + service_split[:house]
        self.agency_total = agency_subtotal - account_total - house_subtotal
        self.agency_net = house_agency ? 0 : agency_total + service_split[:agency]

        total_check = agency_total + account_total + house_subtotal + carrier_total
        total_difference = (subtotal - total_check)
        self.carrier_total = carrier_total + total_difference

        save
      end
    end
end
