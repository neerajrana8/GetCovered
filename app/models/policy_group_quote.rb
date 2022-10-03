# == Schema Information
#
# Table name: policy_group_quotes
#
#  id                          :bigint           not null, primary key
#  reference                   :string
#  external_reference          :string
#  status                      :integer
#  status_updated_on           :datetime
#  premium                     :integer
#  tax                         :integer
#  est_fees                    :integer
#  total_premium               :integer
#  agency_id                   :bigint
#  account_id                  :bigint
#  policy_application_group_id :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  policy_group_id             :bigint
#
class PolicyGroupQuote < ApplicationRecord
  include CarrierPensioPolicyQuote
  include InvoiceableQuote

  belongs_to :policy_application_group
  belongs_to :policy_group, optional: true
  belongs_to :account, optional: true
  belongs_to :agency, optional: true

  has_one :policy_group_premium
  has_many :policy_applications, through: :policy_application_group
  has_many :policy_quotes
  has_many :policy_premiums, through: :policy_quotes
  has_many :invoices, as: :invoiceable
  has_many :model_errors, as: :model, dependent: :destroy

  before_save :set_status_updated_on, if: proc { |quote| quote.status_changed? }

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2,
                 quote_failed: 3, accepted: 4, declined: 5,
                 abandoned: 6, expired: 7, error: 8 }

  def calculate_premium
    policy_group_premium.destroy if policy_group_premium.present?
    self.policy_group_premium = PolicyGroupPremium.create(billing_strategy: policy_application_group.billing_strategy)
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
    if policy_group.nil? && policy_group_premium.calculation_base.positive?

      invoices.external.update_all status: 'managed_externally'
      invoices.internal.order('due_date').each_with_index do |invoice, index|
        invoice.update status: index.zero? ? 'available' : 'upcoming'
      end
      invoices.internal.order('due_date').first&.pay(stripe_source: :default)
    else
      {
        success: false,
        error: 'Quote ineligible for acceptance'
      }
    end
  end

  private

  def try_update_and_start
    start_billing_result = start_billing
    if start_billing_result[:success]
      update(status: :accepted)
      try_bind_request
    else
      set_error(:policy_group_quote_was_not_accepted, start_billing_result[:error])
      {
        success: false,
        message: start_billing_result[:error]
      }
    end
  end

  def try_bind_request
    if bind_request[:error]
      message = 'Unable to bind policy'
      set_error(:policy_group_quote_was_not_accepted, message)
      {
        success: false,
        message: message
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
      message = 'Unable to save policy in system'
      set_error(:policy_group_quote_was_not_accepted, message)
      {
        success: false,
        message: message
      }
    end
  end

  def update_related_entities(policy_group)
    if update(policy_group: policy_group) &&
      policy_application_group.update(policy_group: policy_group, status: 'accepted') &&
      policy_group_premium.update(policy_group: policy_group)
      create_related_policies

      policy_type_identifier = policy_application_group.policy_type_id == 5 ? 'Rental Guarantee' : 'Policy'

      policy_application_group.update(status: :accepted)
      {
        success: true,
        message: "#{policy_type_identifier} Group ##{policy_group.number}, has been accepted."
      }
    else
      # If self.policy, policy_application.policy or policy_premium.policy cannot be set correctly
      update(status: 'error')
      policy_application_group.update(status: :error)
      message = 'Error attaching policy to system'
      set_error(:policy_group_quote_was_not_accepted, message)
      {
        success: false,
        message: message
      }
    end
  end

  def create_related_policies
    policy_quotes.each do |policy_quote|
      ::Policies::CreateFromQuoteJob.perform_later(
        policy_quote,
        policy_status,
        policy_application_group.carrier.integration_designation,
        policy_group
      )
    end
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

  def set_error(kind, message)
    ModelError.create(
      model: self,
      kind: kind,
      information: {
        params: nil,
        policy_users_params: nil,
        errors: {
          message: message
        }
      }
    )
  end
end
