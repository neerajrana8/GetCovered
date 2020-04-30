class PolicyGroupQuote < ApplicationRecord
  PENSIO_BILLING_STRATEGY_ID = 23

  include CarrierPensioPolicyQuote
  include InvoiceableQuote

  belongs_to :policy_application_group
  belongs_to :policy_group, optional: true
  has_one :policy_group_premium, dependent: :destroy
  has_many :policy_applications, through: :policy_application_group
  has_many :policy_quotes
  has_many :policy_premiums, through: :policy_quotes
  has_many :invoices, as: :invoiceable

  before_save :set_status_updated_on, if: proc { |quote| quote.status_changed? }

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2,
                 quote_failed: 3, accepted: 4, declined: 5,
                 abandoned: 6, expired: 7, error: 8 }

  def calculate_premium
    self.policy_group_premium = PolicyGroupPremium.create(billing_strategy_id: PENSIO_BILLING_STRATEGY_ID)
    policy_group_premium.calculate_total
    update(status: :quoted)
  end

  def accept
    if quoted? || error?
      try_update_and_start
    else
      {
        success: false,
        message: 'Quote ineligible for acceptance'
      }
    end
  end

  def available_period
    7.days
  end

  def start_billing
    billing_started = false

    if policy_group.nil? && policy_group_premium.calculation_base.positive? && status == 'accepted'

      invoices.order('due_date').each_with_index do |invoice, index|
        invoice.update status: index.zero? ? 'available' : 'upcoming'
      end
      ap invoices.order('due_date')
      charge_invoice = invoices.order('due_date').first.pay(stripe_source: :default)
      ap charge_invoice
      return true if charge_invoice[:success] == true
    end
    billing_started
  end

  private

  def try_update_and_start
    if update(status: :accepted) && start_billing
      try_bind_request
    else
      {
        success: false,
        message: 'Quote billing failed, unable to write policy'
      }
    end
  end

  def try_bind_request
    if bind_request[:error]
      {
        success: false,
        message: 'Unable to bind policy'
      }
    else
      policy_group = init_policy_group
      try_save_policy_group(policy_group)
    end
  end

  def bind_request
    @bind_request ||= send(bind_method)
  end

  def bind_method
    "#{policy_application_group.carrier.integration_designation}_bind_group"
  end

  def try_save_policy_group(policy_group)
    if policy_group.save
      policy_group.reload

      update_related_entities(policy_group)
    else
      logger.debug policy_group.errors.to_json
      {
        success: false,
        message: 'Unable to save policy in system'
      }
    end
  end

  def update_related_entities(policy_group)
    if update(policy_group: policy_group) &&
      policy_application_group.update(policy_group: policy_group, status: 'accepted') &&
      policy_group_premium.update(policy_group: policy_group)
      create_related_policies

      policy_type_identifier = policy_application_group.policy_type_id == 5 ? 'Rental Guarantee' : 'Policy'

      {
        success: true,
        message: "#{policy_type_identifier} Group ##{policy_group.number}, has been accepted."
      }
    else
      # If self.policy, policy_application.policy or policy_premium.policy cannot be set correctly
      update(status: 'error')
      {
        success: false,
        message: 'Error attaching policy to system'
      }
    end
  end

  def create_related_policies
    policy_quotes.each do |policy_quote|
      policy = policy_quote.build_policy(
        number: get_policy_number,
        status: policy_status,
        billing_status: 'CURRENT',
        effective_date: policy_quote.policy_application.effective_date,
        expiration_date: policy_quote.policy_application.expiration_date,
        auto_renew: policy_quote.policy_application.auto_renew,
        auto_pay: policy_quote.policy_application.auto_pay,
        policy_in_system: true,
        system_purchased: true,
        billing_enabled: true,
        serviceable: policy_quote.policy_application.carrier.syncable,
        policy_type: policy_quote.policy_application.policy_type,
        policy_group: policy_group,
        agency: policy_quote.policy_application.agency,
        account: policy_quote.policy_application.account,
        carrier: policy_quote.policy_application.carrier
      )
      policy.save
      policy.reload

      policy_quote.policy_application.policy_users.each do |pu|
        pu.update(policy: policy)
        pu.user.convert_prospect_to_customer()
      end

      if policy_quote.update(policy: policy) &&
        policy_quote.policy_application.update(policy: policy, status: "accepted") &&
        policy_quote.policy_premium.update(policy: policy)

        PolicyQuoteStartBillingJob.perform_now(policy: policy, issue: issue_policy_method)
      else
        # If self.policy, policy_application.policy or
        # policy_premium.policy cannot be set correctly
        quote_attempt[:message] = "Error attaching policy to system"
        policy_quote.update(status: 'error')
      end
    end
  end

  def get_policy_number
    send("#{policy_application_group.carrier.integration_designation}_generate_number", ::Policy)
  end

  def issue_policy_method
    "#{policy_application_group.carrier.integration_designation}_issue_policy"
  end

  def issue_method
    "#{policy_application_group.carrier.integration_designation}_issue_policy_group"
  end

  def group_policy_number
    @group_policy_number ||=
      case policy_application_group.policy_type.title
      when 'Residential'
        bind_request[:data][:policy_number]
      when 'Commercial'
        external_reference
      when 'Rent Guarantee'
        bind_request[:data][:policy_group_number]
      else
        raise NotImplementedError
      end
  end

  def policy_status
    @policy_status ||=
      case policy_application_group.policy_type.title
      when 'Residential'
        bind_request[:data][:status] == 'WARNING' ? 'BOUND_WITH_WARNING' : 'BOUND'
      when 'Commercial'
        'BOUND'
      when 'Rent Guarantee'
        'BOUND'
      else
        raise NotImplementedError
      end
  end

  def init_policy_group
    build_policy_group(
      number: group_policy_number,
      status: policy_status,
      billing_status: 'CURRENT',
      effective_date: policy_application_group.effective_date,
      expiration_date: policy_application_group.expiration_date,
      auto_renew: policy_application_group.auto_renew,
      auto_pay: policy_application_group.auto_pay,
      policy_in_system: true,
      system_purchased: true,
      billing_enabled: true,
      serviceable: policy_application_group.carrier.syncable,
      policy_type: policy_application_group.policy_type,
      agency: policy_application_group.agency,
      account: policy_application_group.account,
      carrier: policy_application_group.carrier
    )
  end

  def set_status_updated_on
    self.status_updated_on = Time.now
  end
end
