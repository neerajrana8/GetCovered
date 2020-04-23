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

  # ActiveRecord Associations

  belongs_to :invoiceable, polymorphic: true
  belongs_to :payee, polymorphic: true
  
  has_many :charges
  has_many :refunds, through: :charges
  has_many :disputes, through: :charges
  has_many :line_items, autosave: true
  
  has_many :histories, as: :recordable
  #has_many :notifications, as: :eventable

  # Validations

  validates :number, presence: true, uniqueness: true
  validates :subtotal, presence: true
  validates :total, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :due_date, presence: true
  validates :available_date, presence: true
  
  validates_associated :line_items
  validate :term_dates_are_sensible

# 	validate :policy_unless_quoted

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
  
  # issue a proration refund for a completed/processing invoice
  def apply_proration(new_term_last_date, refund_date: nil, to_refund_override: nil, cancel_if_unpaid_override: nil)
    with_lock do
      to_refund = nil
      cancel_if_unpaid = false
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
        to_refund = line_items.group_by{|li| li.refundability }
        to_refund['no_refund'] = 0
        to_refund['prorated_refund'] = (to_refund['prorated_refund'] || []).inject(0){|sum,li| sum + (li.price * proportion_to_refund).floor } if to_refund.has_key?('prorated_refund')
        to_refund['complete_refund_before_term'] = refund_date >= term_first_date ? 0 : to_refund['complete_refund_before_term'].inject(0){|sum,li| sum + li.price } if to_refund.has_key?('complete_refund_before_term')
        to_refund['complete_refund_during_term'] = refund_date > term_last_date ? 0 : to_refund['complete_refund_during_term'].inject(0){|sum,li| sum + li.price } if to_refund.has_key?('complete_refund_during_term')
        to_refund['complete_refund_before_due_date'] = refund_date >= due_date ? 0 : to_refund['complete_refund_before_due_date'].inject(0){|sum,li| sum + li.price } if to_refund.has_key?('complete_refund_before_due_date')
        to_refund = to_refund.transform_values{|v| v.class == ::Array ? 0 : v }.inject(0){|sum,r| sum + r[1] }
      else
        to_refund = to_refund_override
      end
      cancel_if_unpaid = cancel_if_unpaid_override unless cancel_if_unpaid_override.nil?
      # apply refund
      case status
        when 'upcoming', 'available'
          # apply a proration_reduction to the total
          to_refund = subtotal if cancel_if_unpaid
          new_total = subtotal - to_refund
          if new_total < 0
            new_total = 0
            to_refund = subtotal
          end
          if new_total == 0
            return update(proration_reduction: to_refund, total: new_total, status: 'canceled')
          end
          return update(proration_reduction: to_refund, total: new_total)
        when 'complete'
          # apply the refund
          to_refund -= proration_reduction # if a proration was already applied prior to payment and we're prorating again (which can't happen in the current workflow anyway), the proration_reduction was a sort of "pre-refund" and we don't want to refund it twice
          return true if to_refund <= 0
          result = ensure_refunded(to_refund, "Proration Adjustment", nil)
          return true if result[:success]
          return false # WARNING: we discard result[:errors] here
        when 'processing', 'missed'
          return update(has_pending_refund: true, pending_refund_data: { 'proration_refund' => to_refund, 'cancel_if_unpaid' => cancel_if_unpaid })
        when 'canceled'
          # apply a proration_reduction to the total (might as well keep track of changes even to canceled invoices)
          to_refund = subtotal if cancel_if_unpaid
          new_total = subtotal - to_refund
          if new_total < 0
            new_total = 0
            to_refund = subtotal
          end
          return update(proration_reduction: to_refund, total: new_total)
      end
    end
    return false
  end
  
  # refunds whatever is necessary to ensure the total amount refunded is to_refund cents (if it starts above that, it refunds nothing)
  def ensure_refunded(to_refund, full_reason = nil, stripe_reason = nil)
    with_lock do
      return { success: false, errors: "invoice status must be 'complete' before refunding" } unless status == 'complete'
      already_refunded = charges.succeeded.inject(0){|sum, current_charge| sum + current_charge.amount_refunded }
      to_refund_now = [0, to_refund - already_refunded].max
      return apply_refund(to_refund_now, full_reason, stripe_reason)
    end
  end
  
  # refunds an exact amount, regardless of what has been refunded before; or refunds as much of it as possible and reports what it failed to refund
  def apply_refund(to_refund, full_reason = nil, stripe_reason = nil)
    errors_encountered = {}
    with_lock do
      return { success: false, errors: "invoice status must be 'complete' before refunding" } unless status == 'complete'
      charges.succeeded.each do |current_charge|
        to_refund_now = [[current_charge.amount - current_charge.amount_refunded, to_refund].min, 0].max
        result = current_charge.apply_refund(to_refund_now, full_reason, stripe_reason)
        if result[:success]
          to_refund -= to_refund_now
          break if to_refund <= 0
        else
          errors_encountered[current_charge.id] = result[:errors]
        end
      end
    end
    {
      success: to_refund <= 0,
      amount_not_refunded: to_refund,
      errors: {},
      errors_by_charge: errors_encountered
    }
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
    stripe_source = payee.payment_profiles.where(default: true).take&.source_id if stripe_source == :default
    # attempt to make payment
    created_charge = nil
    created_charge = if !stripe_source.nil?    # use specified source
                       charges.create(amount: total, stripe_id: stripe_source)
                     elsif !stripe_token.nil?  # use token
                       charges.create(amount: total, stripe_id: stripe_token)
                     else                      # use charge's default behavior (which right now is to fail with an error message, and shall probably remain such)
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

  def payment_succeeded
    with_lock do
      if self.status == 'processing'
        self.update(status: 'complete')
        invoiceable.payment_succeeded(self) if invoiceable.respond_to?(:payment_succeeded)
        if has_pending_refund && pending_refund_data.has_key?('proration_refund')
          if apply_proration(nil, to_refund_override: pending_refund_data['proration_refund'].to_i, cancel_if_unpaid_override: pending_refund_data['cancel_if_unpaid'])
            update_columns(has_pending_refund: false)
          else
            # WARNING: do nothing on proration application failure... would be a good place for a generalized error to be logged to the db
          end
        end
      end
    end
  end

  def payment_failed
    with_lock do
      if self.status == 'processing'
        invoiceable.payment_failed(self) if invoiceable.respond_to?(:payment_failed)
        if due_date >= Time.current.to_date
          self.update(status: 'available')
        else
          self.payment_missed
        end
      end
    end
  end
  
  def payment_missed
    with_lock do
      if self.status == 'available' || self.status == 'processing' # other statuses mean we were canceled or already paid
        self.update(status: 'missed')
        if self.has_pending_refund && self.pending_refund_data.has_key?('proration_refund')
          if apply_proration(nil, to_refund_override: pending_refund_data['proration_refund'].to_i, cancel_if_unpaid_override: pending_refund_data['cancel_if_unpaid'])
            update(has_pending_refund: false)
          else
            # WARNING: do nothing on proration application failure... would be a good place for a generalized error to be logged to the db
          end
        end
        invoiceable.payment_missed(self) if invoiceable.respond_to?(:payment_missed) && !self.reload.status == 'canceled' # just in case apply_proration reduced our total due to 0 and we are now canceled instead of missed
      end
    end
  end
  
  # returns a descriptor for charges
  def get_descriptor
    case(self.invoiceable.nil? ? nil : self.invoiceable_type) # force 'else' case if invoiceable is nil
      when 'Policy'
        "Policy ##{self.invoiceable.number}"
      when 'PolicyQuote'
        "Policy Quote #{self.invoiceable.external_reference}"
      else
        "Product"
    end
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
    self.calculate_subtotal
    self.calculate_total
    if self.errors.blank?
      self.line_items.update_all(priced_in: true)
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
    self.status_changed = Time.now
  end
  
  def set_was_missed
    self.was_missed = true
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
