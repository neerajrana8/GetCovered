# == Schema Information
#
# Table name: policies
#
#  id                             :bigint           not null, primary key
#  number                         :string
#  effective_date                 :date
#  expiration_date                :date
#  auto_renew                     :boolean          default(FALSE), not null
#  last_renewed_on                :date
#  renew_count                    :integer
#  billing_status                 :integer
#  billing_dispute_count          :integer          default(0), not null
#  billing_behind_since           :date
#  status                         :integer
#  status_changed_on              :datetime
#  billing_dispute_status         :integer          default("UNDISPUTED"), not null
#  billing_enabled                :boolean          default(FALSE), not null
#  system_purchased               :boolean          default(FALSE), not null
#  serviceable                    :boolean          default(FALSE), not null
#  has_outstanding_refund         :boolean          default(FALSE), not null
#  system_data                    :jsonb
#  agency_id                      :bigint
#  account_id                     :bigint
#  carrier_id                     :bigint
#  policy_type_id                 :bigint
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  policy_in_system               :boolean
#  auto_pay                       :boolean
#  last_payment_date              :date
#  next_payment_date              :date
#  policy_group_id                :bigint
#  declined                       :boolean
#  address                        :string
#  out_of_system_carrier_title    :string
#  policy_id                      :bigint
#  cancellation_reason            :integer
#  branding_profile_id            :integer
#  marked_for_cancellation        :boolean          default(FALSE), not null
#  marked_for_cancellation_info   :string
#  marked_cancellation_time       :datetime
#  marked_cancellation_reason     :string
#  document_status                :integer          default("absent")
#  force_placed                   :boolean
#  cancellation_date              :date
#  master_policy_configuration_id :integer
#
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
  include Filterable
  include CarrierPensioPolicy
  include CarrierCrumPolicy
  include CarrierQbePolicy
  include CarrierQbeMasterPolicy
  include CarrierMsiPolicy
  include CarrierDcPolicy
  include AgencyConfiePolicy
  include RecordChange

  before_save :sanitize_policy_number
  before_save :set_status_changed_on, if: Proc.new { |policy| policy.status_changed? }

  after_create :schedule_coverage_reminders, if: -> { policy_type&.master_coverage }
  after_create :create_necessary_policy_coverages_for_external, unless: -> { in_system? }
  after_save :update_users_status

  after_save :update_coverage

  after_commit :notify_users, on: [:create, :update], unless: -> { in_system? }

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

  has_many :master_policy_configurations, as: :configurable

  belongs_to :master_policy_configuration, optional: true # NOTE: Master Policy Coverage

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

  has_many :integration_profiles,
    as: :profileable

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
  scope :not_master, -> { where.not(policy_type_id: PolicyType::MASTER_IDS) }

  ## Filterable

  scope :filter_by_policy_in_system, ->(state) {
    where(policy_in_system: state)
  }

  scope :filter_by_agency_id, ->(agency_id) {
    where(agency_id: agency_id)
  }

  scope :filter_by_status, ->(status) {
    where(status: status)
  }

  scope :filter_by_account_id, ->(account_id) {
    where(account_id: account_id)
  }

  scope :filter_by_policy_type_id, ->(policy_type_id) {
    where(policy_type_id: policy_type_id)
  }

  scope :filter_by_number, ->(number) {
    where('number LIKE ?', "%#{number[:like]}%")
  }

  scope :filter_by_carrier_id, ->(carrier_id) {
    where(carrier_id: carrier_id)
  }

  # TODO: Change after controller structure refactoring
  scope :filter_by_users, ->(payload) {
    if payload[:email]
      return where('users.email LIKE ?', "%#{payload['email']['like']}%")
    else
      if payload[:profile].present?
        return where('profiles.full_name LIKE ?', "%#{payload[:profile][:full_name][:like]}%")
      end
      if payload[:id].present?
        return where(users: { id: payload[:id] })
      end
    end
  }

  accepts_nested_attributes_for :policy_premiums,
  :insurables, :policy_users, :policy_insurables, :policy_application, :master_policy_configurations
  accepts_nested_attributes_for :policy_coverages, allow_destroy: true
  #  after_save :update_leases, if: :saved_changes_to_status?

  validate :correct_document_mime_type
  validate :is_allowed_to_update?, on: :update
  validate :status_allowed
  validate :carrier_agency_exists
  validate :force_placement_for_master_coverage_only
  validate :master_policy, if: -> { policy_type&.master_coverage }
  validates :agency, presence: true, if: :in_system?
  validates :carrier, presence: true, if: :in_system?
  validates :number, uniqueness: true

  validates_presence_of :expiration_date, :effective_date, unless: -> { policy_type&.master || policy_type&.master_coverage }

  validate :date_order,
  unless: proc { |pol| pol.effective_date.nil? || pol.expiration_date.nil? }

  #TODO:  WITHOUT_STATUS must be deleted after fix under GCVR2-768 ticket
  enum status: { AWAITING_PAYMENT: 0, AWAITING_ACH: 1, PAID: 2, BOUND: 3, BOUND_WITH_WARNING: 4,
    BIND_ERROR: 5, BIND_REJECTED: 6, RENEWING: 7, RENEWED: 8, EXPIRED: 9, CANCELLED: 10,
    REINSTATED: 11, EXTERNAL_UNVERIFIED: 12, EXTERNAL_VERIFIED: 13, EXTERNAL_REJECTED: 14, WITHOUT_STATUS: nil }

  enum billing_status: { CURRENT: 0, BEHIND: 1, REJECTED: 2, RESCINDED: 3, ERROR: 4, EXTERNAL: 5 }

  enum billing_dispute_status: { UNDISPUTED: 0, DISPUTED: 1, AWAITING_POSTDISPUTE_PROCESSING: 2,
    NOT_REQUIRED: 3 }

  enum renewal_status: { NONE: 0, UPCOMING: 1, REJECTED: 2, PREPARING: 3,
                         PREPARED: 4, PREPARATION_FAILED: 5, PENDING: 6,
                         RENEWED: 7, FAILED: 8 }, _prefix: :renewal

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

  def get_liability
    if self.carrier_id == MsiService.carrier_id
      self.coverages.find{|cov| cov.designation == "1005" }&.limit
    elsif self.carrier_id == QbeService.carrier_id
      self.coverages.find{|cov| cov.designation == "liability" }&.limit
    else
      self.coverages.select{|cov| !(["LiabilityAmount", "Liability", "Liability Amount", "Liability Limit", "LiabilityLimit", "liability", "Liability Coverage", "liability_coverage"] & [cov.designation, cov.title]).blank? }.find{|cov| !cov.limit.nil? && cov.limit != 0 }&.limit
    end || 0
  end

  enum document_status: {
    absent: 0,
    at_hand: 1,
    sent: 2
  }

  enum rejection_reason: {
    liability_not_correct: I18n.t('policy_model.rejection_reasons.liability_not_correct'),
    pm_not_additional_interest: I18n.t('policy_model.rejection_reasons.pm_not_additional_interest'),
    policy_not_active: I18n.t('policy_model.rejection_reasons.policy_not_active'),
    name_not_correct: I18n.t('policy_model.rejection_reasons.name_not_correct'),
    tenants_not_listed: I18n.t('policy_model.rejection_reasons.tenants_not_listed'),
    am_requirement_not_met: I18n.t('policy_model.rejection_reasons.am_requirement_not_met'),
    other: I18n.t('policy_model.rejection_reasons.other')}

  #TODO: need to refactor to enum values for policy-support dashboard too
  def is_rejection_reason_added?(current_rejection_reason)
    self.system_data["rejection_reasons"].map(&:downcase).any?(current_rejection_reason&.downcase)
  end

  def current_quote
    self.policy_quotes.accepted.order('created_at desc').first
  end

  def self.active_statuses
    %w[BOUND BOUND_WITH_WARNING RENEWING RENEWED REINSTATED EXTERNAL_VERIFIED]
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
    'test_policy'     =>          :full_refund,
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

  def carrier_agency_exists
    return unless in_system?

    errors.add(:carrier, I18n.t('policy_model.carrier_agency_must_exist')) unless agency&.carriers&.include?(carrier)
  end

  def force_placement_for_master_coverage_only
    unless self.force_placed.nil?
      errors.add(:force_placed, "Only applicable to Master Policy Coverages") unless self.policy_type_id == ::PolicyType::MASTER_COVERAGE_ID
    end
  end

  def master_policy
    errors.add(:policy, I18n.t('policy_model.must_belong_to_coverage')) unless policy&.policy_type&.master_policy? && policy&.BOUND?
  end

  def schedule_coverage_reminders
    # CoverageReminderJob.set(wait: policy.system_data['send_first_coverage_reminder_in_days'].to_i.days).perform_later(id, true)
    # CoverageReminderJob.set(wait: policy.system_data['send_second_coverage_reminder_in_days'].to_i.days).perform_later(id, false)
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

  def renewal_date
    self.expiration_date&.tomorrow
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
      CarrierQBE::GenerateAndSendEvidenceOfInsuranceJob.perform_now(self)
    when 'qbe_specialty'
      if self.policy_type_id == 3
        qbe_specialty_issue_policy()
      else
        { error: I18n.t('policy_model.no_policy_issue_for_qbe') }
      end
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
    last_active_moment = last_active_moment.end_of_day if last_active_moment.class == ::Date
    reason = reason.to_s
    # Flee on invalid data
    return I18n.t('policy_model.cancellation_reason_invalid') unless self.class.cancellation_reasons.has_key?(reason)
    return I18n.t('policy_model.policy_is_already_cancelled') if self.status == 'CANCELLED'
    return I18n.t('policy_model.cancellation_already_pending') if self.marked_for_cancellation
    # get the current policy quote and prorate
    special_logic = SPECIAL_CANCELLATION_REFUND_LOGIC[reason]
    errors = []
    case special_logic
      when :prorated_refund
       self.policy_premiums.each do |pp|
        errors << pp.prorate(new_last_moment: last_active_moment)
       end
      when :full_refund
        self.policy_premiums.each do |pp|
          pp.policy_premium_items.each do |ppi|
            ppi.line_items.each do |li|
              ::LineItemReduction.create!(
                reason: "Test Policy Refund",
                refundability: 'cancel_or_refund',
                amount_interpretation: 'max_total_after_reduction',
                amount: 0,
                line_item: li
              )
            end
          end
        end
      when :early_cancellation
        max_days_for_full_refund = CarrierPolicyType.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_id).take&.max_days_for_full_refund || 0
        self.policy_premiums.each do |pp|
          if max_days_for_full_refund != 0 && last_active_moment < (self.created_at.to_date + max_days_for_full_refund.days).end_of_day
            pp.policy_premium_items.where(category: ['premium', 'tax']).each do |ppi|
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
          errors << pp.prorate(new_last_moment: last_active_moment)
        end
      else # :no_refund will end up here; by default we don't refund
        self.policy_premiums.each do |pp|
          pp.prorate(new_last_moment: last_active_moment, force_no_refunds: true)
        end
    end
    errors.compact!
    # Mark cancelled or handle proration error
    if errors.blank?
      update_columns(status: 'CANCELLED', cancellation_reason: reason, cancellation_date: last_active_moment.to_date)
      RentGuaranteeCancellationEmailJob.perform_later(self) if self.policy_type.slug == 'rent-guarantee'
    else
      update_columns(
        marked_for_cancellation: true,
        marked_for_cancellation_info: errors.join("\n\n"),
        marked_cancellation_time: last_active_moment,
        marked_cancellation_reason: reason
      )
      return I18n.t('policy_model.proration_failed')
    end
    # done
    return nil
  end

  def bulk_decline
    raise StandardError.new("Outdated broken method")
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
    raise StandardError.new("Outdated broken method")
    amount = bulk_premium_amount
    charge = policy_group&.policy_group_premium&.policy_group_quote&.invoices&.first&.charges&.first
    return if bulk_premium_amount.zero? || charge.nil?

    charge.refunds.create(amount: amount, currency: 'usd')
  end

  def recalculate_policy_premium
    raise StandardError.new("Outdated broken method")
    policy_premiums&.last&.update(base: 0, taxes: 0, total_fees: 0, total: 0, calculation_base: 0, deposit_fees: 0, amortized_fees: 0, carrier_base: 0, special_premium: 0)
    policy_group&.policy_group_premium&.calculate_total
  end

  def subtract_from_future_invoices
    raise StandardError.new("Outdated broken method")
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

  def update_coverage
    time_condition = nil
    if [1,4,5,6].include?(self.policy_type_id)
      time_condition = Time.current.to_date.between?(self.effective_date, self.expiration_date)
    elsif [3,8].include?(self.policy_type_id)
      time_condition = Time.current.to_date >= self.effective_date
    end

    action_method = nil
    if self.persisted?
      if self.previous_changes.has_key?("id") && self.previous_changes["id"][0].nil?
        action_method = :create
      else
        action_method = :update
      end
    elsif self.destroyed?
      action_method = :destroy
    end

    if [:create, :update].include?(action_method) &&
       self.previous_changes.has_key?("status") &&
       self.previous_changes["status"][0] != self.previous_changes["status"][1]

      if Policy.active_statuses.include?(self.status) &&
         self.cancellation_date.nil? &&
         time_condition

        self.insurables.each do |insurable|
          insurable.add_to_covered(self.policy_type_id, self.id)
          insurable.leases.where(status: "current").each do |lease|
            lease.add_to_covered(self.policy_type_id, self.id) if lease.active?
          end
        end
      end

      if ['EXPIRED', 'CANCELLED', 'EXTERNAL_REJECTED'].include?(self.status)

        self.insurables.each do |insurable|
          insurable.remove_from_covered(self.policy_type_id, self.id)
          insurable.leases.each do |lease|
            lease.remove_from_covered(self.policy_type_id, self.id)
          end
        end
      end
    end
  end

  def latest_lease(lease_status: ['current', 'pending'], user_matches: [:all, :primary, :any, :none], prefer_more_users: true, lessees_only: false, current_only: false, future_users: true, fake_now: nil)
    return nil if self.primary_insurable.blank? || self.primary_insurable.leases.blank?
    lease_status = [lease_status] unless lease_status.class == ::Array
    user_matches = [:all, :primary, :any] if user_matches == true
    user_matches.map!{|um| um.to_sym }
    user_matches = [:all] + user_matches unless user_matches.include?(:all) || (user_matches - [:none]).blank?
    found = self.primary_insurable.leases.where(status: lease_status).order(start_date: :desc).sort_by{|l| lease_status.find_index(l.status) }.group_by do |lease|
      lease_users = if current_only
          lease.lease_users.send(*(lessees_only ? [:where, { lessee: true }] : [:itself]))
        else
          lease.active_lease_users(fake_now || Time.current.to_date, **({ lessee: (lessees_only || nil), allow_future: future_users }.compact))
      end
      case lease_users.count{|lu| self.users.any?{|u| u.id == lu.user_id } }
        when self.users.count
          :all
        when 0
          :none
        else
          lease_users.any?{|lu| lu.user_id == self.primary_user&.id } ? :primary : :any
      end
    end
    (user_matches.class == ::Array ? user_matches : [user_matches]).each do |match_type|
      unless found[match_type].blank?
        return(
          (prefer_more_users && [:any, :primary].include?(match_type)) ?
            found[match_type].sort_by do |lease|
              lease_users = if current_only
                  lease.lease_users.send(*(lessees_only ? [:where, { lessee: true }] : [:itself]))
                else
                  lease.active_lease_users(fake_now || Time.current.to_date, **({ lessee: (lessees_only || nil), allow_future: future_users }.compact))
              end
              -lease_users.count{|lu| self.users.any?{|u| u.id == lu.user_id } }
            end.first
            : found[match_type].first
        )
      end
    end
    return nil
  end

  def lease_sign_date
    latest_lease&.sign_date
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

  def update_users_status
    users.each do |user|
      user.update(has_existing_policies: true) if user.policies.present?
    end
  end

  def create_necessary_policy_coverages_for_external
    unless self.policy_coverages.where(designation: "liability").count > 0
      self.policy_coverages.create!(
        title: "Liability",
        designation: "liability",
        limit: 0,
        enabled: true
      )
    end
  end

  def notify_users
    # TODO: ADD GUARD STATEMENTS AND REMOVE NESTED CONDITIONS
    return if self.in_system?
    if previous_changes.has_key?('status') && %w[EXTERNAL_UNVERIFIED EXTERNAL_VERIFIED EXTERNAL_REJECTED CANCELLED].include?(status)
      unless integration_profiles.count.positive? && status == 'EXTERNAL_UNVERIFIED'

        if account_id == 0 || agency_id == 0
          reload() if inline_fix_external_policy_relationships
        end

        #TODO: temp test need to remove according to GCVR2-1197
        begin
          if Rails.env.development? or ENV['RAILS_ENV'] == 'awsdev'
            if CANCELLED?
              Compliance::PolicyMailer.with(organization: self.account.nil? ? self.agency : self.account)
                                      .policy_lapsed(policy: self, lease: self.latest_lease)
                                      .deliver_now
            else
              Compliance::PolicyMailer.with(organization: self.account.nil? ? self.agency : self.account)
                                      .external_policy_status_changed(policy: self)
                                      .deliver_now
            end
          else
            if CANCELLED?
              Compliance::PolicyMailer.with(organization: self.account.nil? ? self.agency : self.account)
                                      .policy_lapsed(policy: self, lease: self.latest_lease)
                                      .deliver_later(wait: 5.minutes)
            else
              Compliance::PolicyMailer.with(organization: self.account.nil? ? self.agency : self.account)
                                      .external_policy_status_changed(policy: self)
                                      .deliver_later(wait: 5.minutes)
            end
          end
        rescue Exception => e
          @error = ModelError.create!(
            kind: "external_policy_status_change_notification_error",
            model_type: "Policy",
            model_id: id,
            information: e.to_json,
            backtrace: e.backtrace.to_json,
            description: "Unable to generate external Policy status change email for Policy ID: #{ id }<br><br>"
          )
        end
      end
    end
  end

  def sanitize_policy_number
    self.number = self.number&.strip
  end

  def set_status_changed_on
    self.status_changed_on = DateTime.current
    essex_webhook_check = Rails.env == "awsdev" ? 28 : Rails.env == "production" ? 45 : false
    Policies::SendWebhookJob.perform_later(policy_id: self.id) if essex_webhook_check != false && self.account_id == essex_webhook_check
  end

  def inline_fix_external_policy_relationships
    return true
    # the below is commented out because it was breaking upload
=begin
    to_return = false
    to_save = false
    account_condition = (self.account_id.nil? || self.account_id == 0)
    agency_condition = (self.agency_id.nil? || self.agency_id == 0)
    unless self.policy_in_system
      if account_condition || agency_condition
        insurable = policy.primary_insurable

        if account_condition
          unless insurable.account_id == 0 || insurable.account_id.nil?
            self.account_id = insurable.account_id
            to_return = true
            to_save = true
          end
        end

        if agency_condition
          unless self.account_id.nil? || self.account_id == 0
            self.agency_id = Account.find(insurable.account_id).agency_id
            to_return = true
            to_save = true
          end
        end

        self.save! if to_save

      end
    end
    return to_return
=end
  end
end
