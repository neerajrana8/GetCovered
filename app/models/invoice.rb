# frozen_string_literal: true

# Invoice model
# file: app/models/invoice.rb

class Invoice < ApplicationRecord
  # ActiveRecord Callbacks

  # All initialization was moved to database. Only user assignment is left, 
  # which will be uncommented when Policy is ready.
  # after_initialize  :initialize_invoice

  before_validation :calculate_subtotal, if: -> { line_items.count > 0 }

  before_validation :set_number, on: :create

  before_save :set_status_changed, if: -> { status_changed? }

  # ActiveRecord Associations

  belongs_to :policy

  belongs_to :user

  has_many :charges

  has_many :refunds, through: :charges

  has_many :disputes, through: :charges

  has_many :line_items, autosave: true

  has_many :modifiers

  has_many :histories, as: :recordable

  has_many :notifications, as: :notifiable

  # Validations

  validates :number, presence: true, uniqueness: true

  validates :subtotal, presence: true

  validates :total, presence: true

  validates :status, presence: true

  validates :due_date, presence: true

  validates :available_date, presence: true

  validates :tax, presence: true

  validates :tax_percent, presence: true

  validates :policy, presence: true

  validates :user, presence: true

  accepts_nested_attributes_for :line_items

  # Enums

  enum status: %w[upcoming available processing complete missed canceled]

  scope :unpaid, -> { where(status: %w[available missed]) }
  scope :unpaid_past_due, -> { 
    where(status: %w[available missed]).where('due_date < ?', DateTime.now)
  }

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

  def apply_proration(new_term_last_date)
    return true if term_first_date.nil? || term_last_date.nil?

    if new_term_last_date < term_first_date
      # this invoice's term falls entirely after the period requiring payment; cancel
      case status
      when 'upcoming', 'available'
        return update(status: 'canceled')
      when 'processing', 'complete'
        return refund_proportion(1.0, 'proration adjustment')
      when 'missed', 'canceled'
        return true
      end
    elsif new_term_last_date > term_last_date
      # this invoice's term falls entirely before the period requiring payment; do nothing
      return true
    else
      # the date of proration falls within this invoice's term; prorate
      proportion_to_refund = (term_last_date - new_term_last_date).to_f / (term_last_date + 1.day - term_first_date).to_f
      return true if proportion_to_refund == 0.0

      case status
      when 'upcoming', 'available'
        return update(status: 'canceled')
      when 'processing', 'complete'
        return refund_proportion(proportion_to_refund, 'proration adjustment')
      when 'missed', 'canceled'
        return true
      end
    end
    false # control should never reach this line
  end

  # Refund Proportion
  #
  # Perform a refund for a certain proportion (as a decimal) of the total.
  # This method takes prior refunds into account; that is, if 50% has been refunded
  # already, refund_proportion(0.75) will refund an additional 25%.
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   @invoice.refund_proportion(0.5, "refunding half sounded good", nil)
  #   => true

  def refund_proportion(proportion, full_reason = nil, stripe_reason = nil)
    reload
    case status
    when 'complete'
      to_refund = [(proportion * total.to_f).floor.to_i - amount_refunded, 0].max
      return true if to_refund == 0

      result = apply_refund(to_refund, full_reason, stripe_reason)
      return true if result[:success]

      # try again if somehow we failed
      to_refund = result[:amount_not_refunded]
      result = apply_refund(to_refund, full_reason, stripe_reason)
      return true if result[:success]

      # fail sadly WARNING: we discard result[:errors] here... but if this method is called again, amount_refunded should be updated according to any successful refunds, so it should cause no problems
      return false
    when 'processing'
      succeeded = false
      with_lock do
        unless has_pending_refund && pending_refund_data['proportion'] && pending_refund_data['proportion'] > proportion
          self.pending_refund_data = {
            'proportion' => proportion,
            'full_reason' => full_reason,
            'stripe_reason' => stripe_reason
          }
        end
        self.has_pending_refund = true
        succeeded = save
      end
      return succeeded
    else
      return false
    end
  end

  # Apply Refund
  #
  # Perform a refund for a certain number of cents. If it cannot all be
  # refunded, it will refund as much as possible and make the left-over
  # amount available in its return value.
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   @invoice.apply_refund(5100, "I just felt like refunding this", nil)
  #   => { success: true, amount_not_refunded: 0, errors_by_charge: {} }

  def apply_refund(to_refund, full_reason = nil, stripe_reason = nil)
    errors_encountered = {}
    charges.succeeded.each do |current_charge|
      to_refund_now = [[current_charge.amount - current_charge.amount_refunded, to_refund].min, 0].max
      result = current_charge.apply_refund(to_refund_now, full_reason, stripe_reason)
      if result[:success]
        to_refund -= to_refund_now
        break if to_refund == 0
      else
        errors_encountered[current_charge.id] = result[:errors]
      end
    end
    {
      success: to_refund == 0,
      amount_not_refunded: to_refund,
      errors_by_charge: errors_encountered
    }
  end

  # Calculate Total
  #
  # Apply modifiers and tax to subtotal to calculate total
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   payment_method = [ nil, 'card', 'bank_account' ][rand(3)]
  #   @invoice.calculate_total(payment_method)
  #   => nil

  def calculate_total(payment_method, and_save = true)
    # setup
    prereceipt = {}
    payment_method = nil unless %w[card bank_account].include?(payment_method)
    float_total = subtotal.to_f / 100.0
    # add subtotal and line items to prereceipt
    prereceipt['subtotal'] = subtotal
    prereceipt['items'] = []
    line_items.each do |line_item|
      prereceipt['items'].push({ type: 'flat' }.merge(name: line_item.title, price: line_item.price))
    end
    # apply modifiers
    modifiers.create(strategy: 'percentage', amount: 1.10, condition: 'card_payment') if payment_method == 'card' && modifiers.where(condition: 'card_payment').count == 0
    modifier_array = modifiers.to_a
    Modifier.pretax_tiers_in_order.each do |current_tier|
      # apply percentage changes
      current_coefficient = 1.0
      modifier_array.each do |current_modifier|
        if current_modifier.tier == current_tier && current_modifier.strategy == 'percentage' && current_modifier.should_apply?(payment_method)
          current_coefficient *= current_modifier.amount
        end
      end
      float_total *= current_coefficient
      # apply flat changes
      modifier_array.each do |current_modifier|
        if current_modifier.tier == current_tier && current_modifier.strategy == 'flat' && current_modifier.should_apply?(payment_method)
          float_total += current_modifier.amount / 100.0
        end
      end
    end
    # calculate tax and the final total
    float_total = (float_total * 100.0).ceil # express in cents and round up
    pretax_total = float_total               # grab
    float_total /= 100.0                     # express in dollars again
    float_total *= (1.0 + tax_percent) unless tax_percent.nil? # apply tax
    float_total = (float_total * 100.0).ceil # express in cents and round up
    # set tax & total
    self.tax = float_total.to_i - pretax_total.to_i
    self.total = float_total.to_i
    prereceipt['tax'] = tax
    prereceipt['total'] = total
    unless pretax_total.to_i == subtotal
      prereceipt['items'].push(
        'type' => 'flat',
        'name' => 'Service Fee',
        'price' => pretax_total.to_i - subtotal
      )
    end
    unless tax == 0
      prereceipt['items'].push(
        'type' => 'flat',
        'name' => 'Tax',
        'price' => tax
      )
    end
    # all done

    system_data['prereceipt'] = prereceipt

    # Either need to refactor set_commission or remove it.
    # if and_save
    #   set_commission if save
    # end
    prereceipt
  end

  # Pay
  #
  # Build charge and sync to stripe
  #
  # Example:
  #   @invoice = Invoice.find(1)
  #   @invoice.pay()
  #   => { success: true }

  def pay(allow_upcoming: false, amount_override: nil, stripe_source: nil, stripe_token: nil) # all optional
    # set invoice status to processing
    return_error = nil
    with_lock do
      unless ((allow_upcoming && status == 'upcoming') || status == 'available') && update(status: 'processing', total: amount_override || total)
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

    # attempt to make payment
    created_charge = nil
    created_charge = if !stripe_source.nil? # use one-time source
                       charges.create(amount: total, stripe_id: stripe_source)
                     elsif !stripe_token.nil?  # use token
                       charges.create(amount: total, stripe_id: stripe_token)
                     else                      # use default payment method
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
    update(status: 'complete')
    reload

    if has_pending_refund
      if refund_proportion(pending_refund_data['proportion'], pending_refund_data['full_reason'], pending_refund_data['stripe_reason'])
        update(has_pending_refund: false)
      end
    end

    if policy.behind_billing_status? || policy.rejected_billing_status?
      invoices = policy.invoices
      invoices_statuses = []
      invoices.each { |i| invoices_statuses << i.status }

      policy.billing_status = 'rescinded' unless invoices_statuses.include? 'missed'
    else
      policy.billing_status = 'current'
    end

    policy.last_payment_date = updated_at.to_date
    next_invoice = policy.invoices.order('due_date ASC').where('due_date > ?', due_date).limit(1).take
    policy.next_payment_date = next_invoice.due_date unless next_invoice.nil?

    policy.save
  end

  def payment_failed
    unless status == 'complete'

      failure_is_postproration = false # flag set to true when this is a post-policy-proration failure of a canceled policy

      if due_date >= Time.current.to_date
        invoice_status = 'available'
        user_notification_subject = 'Get Covered: Policy Payment Failure'
        user_notification_message = "A payment for your renters insurance policy ##{policy.number}, invoice ##{number} has failed.  Please submit another payment before #{due_date.strftime('%m/%d/%Y')}."
        agent_notification_subject = 'Get Covered: Policy Payment Failure'
        agent_notification_message = "A payment for renters insurance policy ##{policy.number}, invoice ##{number} has failed.  Payment due #{due_date.strftime('%m/%d/%Y')}."
      else
        invoice_status = 'missed'
        user_notification_subject = 'Get Covered: Policy behind'
        user_notification_message = "A payment for your renters insurance policy ##{policy.number}, invoice ##{number} has failed.  Your policy is now past due.  Please submit a payment immediately to prevent cancellation of coverage."
        agent_notification_subject = 'Get Covered: Policy behind'
        agent_notification_message = "A payment for renters insurance policy ##{policy.number}, invoice ##{number} has failed.  This policy is now past due."
      end

      update status: invoice_status
      if invoice_status == 'missed'
        if has_pending_refund
          # if we are here, then a proration was applied to the invoice while payment was processing, and payment then failed
          failure_is_postproration = true
          agent_notification_subject = 'Get Covered: Post-Cancelation Policy Payment Failure'
          agent_notification_message = "A payment for renters insurance policy ##{policy.number}, invoice #{number} has failed. The payment was marked for proration adjustments via refund upon success, because the policy was canceled while the payment was being processed. No proration adjustment refunds will be issued; no payment was collected for this invoice."
          notifications.create(
            notifiable: SystemDaemon.find_by_process('notify_canceled_policy_payment_failure'),
            action: 'invoice_payment_failed_after_proration',
            subject: agent_notification_subject,
            message: agent_notification_message
          )
        end
        policy.update billing_status: 'behind'
      end

      # Find agents to notify
      policy_agents = policy.agency.account_staff

      # Notify responsible user
      unless failure_is_postproration
        notifications.create(
          notifiable: user,
          action: 'invoice_payment_failed',
          subject: user_notification_subject,
          message: user_notification_message
        )
      end

      # Notify policy agents
      policy_agents.each do |agent|
        notifications.create(
          notifiable: agent,
          action: failure_is_postproration ? 'invoice_payment_failed_after_proration' : 'invoice_payment_failed',
          subject: agent_notification_subject,
          message: agent_notification_message
        )
      end

    end
  end

  # Make available
  #
  # Sets invoice as available

  def make_available
    if status == 'upcoming'
      if update status: 'available'

        calculate_total(user.current_payment_method == 'none' ? nil : user.current_payment_method == 'card' ? 'card' : 'bank_account', true)

        user_notification = notifications.new(
          notifiable: user,
          action: 'invoice_available',
          template: 'invoice',
          subject: "Policy #{policy.policy_number} #{number}.",
          message: 'A new invoice is available for payment.'
        )

        if user_notification.save

        else
          pp user_notification.errors
        end

      end
    end
  end

  private

  def initialize_invoice
    self.user ||= policy&.user
  end

  # Calculation Methods

  def calculate_subtotal(and_save = false)
    prior_subtotal = subtotal
    self.subtotal = line_items.inject(0) { |result, line_item| result += line_item.price }
    calculate_total(self.user.nil? || self.user.current_payment_method == 'none' ? nil : self.user.current_payment_method == 'card' ? 'card' : 'bank_account', and_save) if subtotal != prior_subtotal
  end

  # History Methods

  def history_whitelist
    [:status]
  end

  def related_classes_through
    [:policy]
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

  # This method uses deprecated fields (e.g. agency_total).
  # Either refactor it or delete.
  def set_commission
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
