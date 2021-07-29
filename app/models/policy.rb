##
# =Policy Model
# file: +app/models/policy.rb+
#
# All that is evil... the Policy model stalks the application
# with silent precision.  Wreaking havoc on everything and everyone
# who touches it.  Fear what lies ahead.
#
# - Dylan Gaines (added sometime in 2017)
#
# Attributes:
# +number+:: (String) A unique policy number provided for synced policies by QBE.  Indexed.
# +effective_date+:: (Date) The date coverage will start.
# +expiration_date+:: (Date) The final day of coverage.
# +auto_renew+:: (Boolean)
# +last_renewed_on+:: (Date)
# +renew_count+:: (Integer)
# +billing_status+:: (Integer)
# +billing_dispute_count+:: (Integer)
# +billing_behind_since+:: (Date)
# +cancellation_reason+:: (Integer)
# +cancellation_date+:: (Date)
# +status+:: (Integer)
# +status_changed_on+:: (DateTime)
# +billing_dispute_status+:: (Integer)
# +billing_enabled+:: (Boolean)
# +system_purchased+:: (Boolean)
# +serviceable+:: (Boolean)
# +has_outstanding_refund+:: (Boolean)
# +system_data+:: (Jsonb)
# +agency_id+:: (Bigint)
# +account_id++:: (Bigint)
# +carrier_id++:: (Bigint)
# +policy_type_id++:: (Bigint)
# +billing_profie_id++:: (Bigint)
# +created_at+:: (DateTime) The date time of model creation
# +updated_at+:: (DateTime) The last date time model was successfuly edited

class Policy < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include CarrierPensioPolicy
  include CarrierCrumPolicy
  include CarrierQbePolicy
  include CarrierMsiPolicy
  include CarrierDcPolicy
  include AgencyConfiePolicy
  include RecordChange

  after_create :schedule_coverage_reminders, if: -> { policy_type&.designation == 'MASTER-COVERAGE' }

  # after_save :start_automatic_master_coverage_policy_issue, if: -> { policy_type&.designation == 'MASTER' }

  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :branding_profile, optional: true
  belongs_to :carrier, optional: true
  belongs_to :policy_type, optional: true
  # belongs_to :billing_profie
  belongs_to :policy_group_quote, optional: true
  belongs_to :policy_group, optional: true
  belongs_to :policy, optional: true

  has_many :policy_insurables, inverse_of: :policy
  has_many :insurables, through: :policy_insurables
  has_many :policies
  has_many :claims

  has_many :events, as: :eventable

  has_many :policy_quotes
  has_one :policy_application

  has_many :policy_users
  has_many :users, through: :policy_users


  has_many :policy_rates
  has_many :insurable_rates,
  through: :policy_rates, before_add: :check_if_active

  has_one :primary_policy_user, -> { where(primary: true) },
  class_name: 'PolicyUser'

  has_one :primary_user,
  class_name: 'User',
  through: :primary_policy_user,
  source: :user

  has_one :primary_policy_insurable, -> { where(primary: true) }, class_name: 'PolicyInsurable'
  has_one :primary_insurable, class_name: 'Insurable', through: :primary_policy_insurable, source: :insurable

  has_many :policy_coverages, autosave: true
  has_many :coverages, -> { where(enabled: true) },
  class_name: 'PolicyCoverage'

  has_many :policy_premiums, autosave: true
  # has_one :premium, -> { find_by(enabled: true) }, class_name: 'PolicyPremium'

  has_many :invoices, through: :policy_quotes
  has_many :master_policy_invoices, as: :invoiceable, class_name: 'Invoice'
  has_many :charges, through: :invoices

  has_many :refunds, through: :charges

  has_many :commission_deductions

  has_many :histories, as: :recordable
  has_many :change_requests, as: :changeable

  has_many :signable_documents, as: :referent

  has_many_attached :documents

  def carrier_agency; @crag ||= ::CarrierAgency.where(carrier_id: self.carrier_id, agency_id: self.agency_id).take; end

  # Scopes
  scope :current, -> { where(status: %i[BOUND BOUND_WITH_WARNING]) }
  scope :not_active, -> { where.not(status: %i[BOUND BOUND_WITH_WARNING]) }
  scope :policy_in_system, ->(policy_in_system) { where(policy_in_system: policy_in_system) }
  scope :unpaid, -> { where(billing_status: ['BEHIND', 'REJECTED']) }
  scope :in_system?, ->(in_system) { where(policy_in_system: in_system) }
  scope :with_missed_invoices, lambda {
    joins(:invoices).merge(Invoice.unpaid_past_due)
  }

  scope :accepted_quote, lambda {
    joins(:policy_quotes).where(policy_quotes: { status: 'accepted'})
  }
  scope :master_policy_coverages, -> { where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS) }

  accepts_nested_attributes_for :policy_premiums,
  :insurables, :policy_users, :policy_insurables, :policy_application
  accepts_nested_attributes_for :policy_coverages, allow_destroy: true
  #  after_save :update_leases, if: :saved_changes_to_status?

  after_commit :update_insurables_coverage,
             if: Proc.new{ saved_change_to_status? || saved_change_to_effective_date? || saved_change_to_effective_date? }
  after_destroy_commit :update_insurables_coverage

  validate :correct_document_mime_type
  validate :is_allowed_to_update?, on: :update
  validate :residential_account_present
  validate :status_allowed
  validate :carrier_agency_exists
  validate :master_policy, if: -> { policy_type&.designation == 'MASTER-COVERAGE' }
  validates :agency, presence: true, if: :in_system?
  validates :carrier, presence: true, if: :in_system?
  validates :number, uniqueness: true

  validates_presence_of :expiration_date, :effective_date, unless: -> { ['MASTER-COVERAGE', 'MASTER'].include?(policy_type&.designation) }

  validate :date_order,
  unless: proc { |pol| pol.effective_date.nil? || pol.expiration_date.nil? }

  enum status: { AWAITING_PAYMENT: 0, AWAITING_ACH: 1, PAID: 2, BOUND: 3, BOUND_WITH_WARNING: 4,
    BIND_ERROR: 5, BIND_REJECTED: 6, RENEWING: 7, RENEWED: 8, EXPIRED: 9, CANCELLED: 10,
    REINSTATED: 11, EXTERNAL_UNVERIFIED: 12, EXTERNAL_VERIFIED: 13 }

  enum billing_status: { CURRENT: 0, BEHIND: 1, REJECTED: 2, RESCINDED: 3, ERROR: 4, EXTERNAL: 5 }

  enum billing_dispute_status: { UNDISPUTED: 0, DISPUTED: 1, AWAITING_POSTDISPUTE_PROCESSING: 2,
    NOT_REQUIRED: 3 }

  enum cancellation_code: { # WARNING: remove this, it's old
    AP: 0,
    AR: 1,
    IR: 2,
    NP: 3,
    UW: 4,
    TEST: 5
  }

  enum cancellation_reason: {
    nonpayment:                 0,    # QBE AP
    agent_request:              1,    # QBE AR
    insured_request:            2,    # QBE IR
    new_application_nonpayment: 3,    # QBE NP
    underwriter_cancellation:   4,    # QBE UW
    disqualification:           5,    # no qbe code
    test_policy:                6,     # no qbe code
    manual_cancellation_with_refunds:     7,     # no qbe code
    manual_cancellation_without_refunds:  8    # no qbe code
  }
  
  def current_quote
    self.policy_quotes.accepted.order('created_at desc').first
  end

  def self.active_statuses
    ['BOUND', 'BOUND_WITH_WARNING', 'RENEWING', 'RENEWED', 'REINSTATED']
  end

  def is_active?
    self.class.active_statuses.include?(self.status)
  end

  def was_active?
    self.class.active_statuses.include?(self.attribute_before_last_save('status'))
  end

  # Cancellation reasons with special refund logic; allowed values:
  #   early_cancellation:       within the first (CarrierInsurableType.max_days_for_full_refund || 30) days a refund will be issued equivalent to a refund prorated for the day before the policy's effective_date
  #   no_refund:                no refund will be issued, but available/upcoming/missed invoices will be cancelled, and processing invoices will be cancelled if they fail (but not refunded if they succeed)

  SPECIAL_CANCELLATION_REFUND_LOGIC = {
    'insured_request' =>          :early_cancellation,
    'nonpayment'      =>          :no_refund,
    'test_policy'     =>          :no_refund,
    'manual_cancellation_with_refunds' => :early_cancellation,
    'manual_cancellation_without_refunds' => :no_refund
  }

  def in_system?
    policy_in_system == true
  end

  def premium
    policy_premiums.where(enabled: true).take
  end

  # PolicyApplication.primary_insurable

  # def primary_insurable
  #   policy_insurable = policy_insurables.where(primary: true).take
  #   policy_insurable&.insurable
  # end

  def is_allowed_to_update?
    errors.add(:policy_in_system, I18n.t('policy_model.cannot_update')) if policy_in_system == true && !rent_garantee? && !residential?
  end

  def residential_account_present
    errors.add(:account, I18n.t('policy_model.account_must_be_specified')) if ![4,5].include?(policy_type_id) && account.nil? && !self.primary_insurable&.account.nil?
  end

  def carrier_agency_exists
    return unless in_system?

    errors.add(:carrier, I18n.t('policy_model.carrier_agency_must_exist')) unless agency&.carriers&.include?(carrier)
  end

  def master_policy
    errors.add(:policy, I18n.t('policy_model.must_belong_to_coverage')) unless policy&.policy_type&.master_policy? && policy&.BOUND?
  end

  def schedule_coverage_reminders
    CoverageReminderJob.set(wait: policy.system_data['send_first_coverage_reminder_in_days'].to_i.days).perform_later(id, true)
    CoverageReminderJob.set(wait: policy.system_data['send_second_coverage_reminder_in_days'].to_i.days).perform_later(id, false)
  end

  def start_automatic_master_coverage_policy_issue
    AutomaticMasterCoveragePolicyIssueJob.perform_later(id)
  end

  def status_allowed
    if in_system?
      if (AWAITING_PAYMENT? || AWAITING_ACH?) && invoices.paid.count.zero?
        errors.add(:status, I18n.t('policy_model.must_have_paid_invoice'))
      end
    end
  end

  def premium
    return policy_premiums.order("created_at").last
  end
  
  def effective_moment
    self.effective_date.beginning_of_day
  end
  
  def expiration_moment
    self.expiration_date.end_of_day
  end

  def update_leases
    if BOUND? || RENEWED? || REINSTATED?
      insurables.each do |insurable|
        insurable.leases.each do |lease|
          lease.update_attribute(:covered, true) if lease.current?
        end
      end
    elsif EXPIRED? || CANCELLED?
      insurables.each do |insurable|
        insurable.leases.each do |lease|
          lease.insurable.policies.each do |policy|
            return if policy.PAID? || policy.BOUND? || policy.RENEWED? || policy.REINSTATED?
          end
          lease.update_attribute(:covered, false)
        end
      end
    end
  end

  def issue
    case policy_application&.carrier&.integration_designation
    when 'qbe'
      qbe_issue_policy
    when 'qbe_specialty'
      { error: I18n.t('policy_model.no_policy_issue_for_qbe') }
    when 'crum'
      crum_issue_policy
    when 'msi'
      msi_issue_policy
    when 'dc'
      dc_issue_policy
    else
      { error: I18n.t('policy_model.error_with_policy')  }
    end
  end


  # Cancels a policy; returns nil if no errors, otherwise a string explaining the error
  def cancel(reason, last_active_moment = Time.current.to_date.end_of_day)
    # Flee on invalid data
    return I18n.t('policy_model.cancellation_reason_invalid') unless self.class.cancellation_reasons.has_key?(reason)
    return I18n.t('policy_model.policy_is_already_cancelled') if self.status == 'CANCELLED'
    return I18n.t('policy_model.cancellation_already_pending') if self.marked_for_cancellation
    # get the current policy quote and prorate
    pq = self.current_quote
    special_logic = SPECIAL_CANCELLATION_REFUND_LOGIC[reason]
    result = nil
    case special_logic
      when :prorated_refund
       result =  pq.policy_premium.prorate(new_last_moment: last_active_moment)
      when :early_cancellation
        max_days_for_full_refund = (CarrierPolicyType.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_id).take&.max_days_for_full_refund || 0).days
        if last_active_moment < (self.created_at.to_date + max_days_for_full_refund.days).end_of_day
          pq.policy_premium.policy_premium_items.where(category: ['premium', 'tax']).each do |ppi|
            ppi.line_items.each do |li|
              ::LineItemReduction.create!(
                reason: "Early Cancellation Refund",
                refundability: 'cancel_or_refund',
                amount_interpretation: 'max_total_after_reduction',
                amount: 0,
                line_item: li
              )
            end
          end
        end
        result = pq.policy_premium.prorate(new_last_moment: last_active_moment)
      else # :no_refund will end up here; by default we don't refund
        result = pq.policy_premium.prorate(new_last_moment: last_active_moment, force_no_refunds: true)
    end
    # Handle proration error
    unless result.nil?
      update_columns(
        marked_for_cancellation: true,
        marked_for_cancellation_info: result,
        marked_cancellation_time: last_active_moment,
        marked_cancellation_reason: reason
      )
      return I18n.t('policy_model.proration_failed')
    end
    # Mark cancelled
    update_columns(status: 'CANCELLED', cancellation_reason: reason, cancellation_date: last_active_moment.to_date)
    RentGuaranteeCancellationEmailJob.perform_later(self) if self.policy_type.slug == 'rent-guarantee'
    # done
    return nil
  end

  def bulk_decline
    update_attribute(:declined, true)
    generate_refund if created_at > 1.month.ago
    subtract_from_future_invoices
    recalculate_policy_premium
  end

  def bulk_premium_amount
    premium = policy_premiums&.last&.total || 0
    terms = policy_premiums&.last&.billing_strategy&.new_business&.[]('payments_per_term') || 12
    amount = premium / terms
    amount
  end

  def generate_refund
    amount = bulk_premium_amount
    charge = policy_group&.policy_group_premium&.policy_group_quote&.invoices&.first&.charges&.first
    return if bulk_premium_amount.zero? || charge.nil?

    charge.refunds.create(amount: amount, currency: 'usd')
  end

  def recalculate_policy_premium
    throw "Policy#recalculate_policy_premium is currently broken!" # MOOSE WARNING
    policy_premiums&.last&.update(base: 0, taxes: 0, total_fees: 0, total: 0, calculation_base: 0, deposit_fees: 0, amortized_fees: 0, carrier_base: 0, special_premium: 0)
    policy_group&.policy_group_premium&.calculate_total
  end

  def subtract_from_future_invoices
    amount = bulk_premium_amount
    policy_group&.policy_group_premium&.policy_group_quote&.invoices&.each do |invoice|
      line_item = invoice.line_items.base_premium.take
      line_item.price = line_item.price - amount
      line_item.save
      invoice.refresh_totals
    end
  end

  def residential?
    policy_type == PolicyType.residential
  end

  def rent_garantee?
    policy_type == PolicyType.rent_garantee
  end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :number, type: :text
    end
  end

  def refund_available_days
    max_days_for_full_refund =
      (CarrierPolicyType.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_id).
        take&.max_days_for_full_refund || 0).
        days - 1.day
    raw_days = (self.created_at.to_date + max_days_for_full_refund - Time.zone.now.to_date).to_i
    raw_days.negative? ? 0 : raw_days
  end

  def run_postbind_hooks # do not remove this; concerns add functionality to it by overriding it and calling super
    notify_relevant()
    super if defined?(super)
  end

  private

  def notify_relevant
    Policies::PurchaseNotifierJob.perform_later(self.id)
  end

  def date_order
    errors.add(:expiration_date, I18n.t('policy_app_model.expiration_date_cannot_be_before_effective')) if expiration_date < effective_date
  end

  def correct_document_mime_type
    documents.each do |document|
      if !document.blob.content_type.starts_with?('image/png', 'image/jpeg', 'image/jpg', 'image/svg',
        'image/gif', 'application/pdf', 'text/plain', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/comma-separated-values', 'application/vnd.ms-excel'
        )
        errors.add(:documents, I18n.t('policy_model.document_wrong_format'))
      end
    end
  end

  def update_insurables_coverage
    insurables.each { |insurable| Insurables::UpdateCoveredStatus.run!(insurable: insurable) }
  end
end
