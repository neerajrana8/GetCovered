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
  scope :in_system?, ->(in_system) { where(policy_in_system: in_system) }
  scope :with_missed_invoices, lambda {
    joins(:invoices).merge(Invoice.unpaid_past_due)
  }
  
  scope :accepted_quote, lambda {
    joins(:policy_quotes).where(policy_quotes: { status: 'accepted'})
  }
  
  # Concerns
  include ElasticsearchSearchable
  include CarrierPensioPolicy
  include CarrierCrumPolicy
  include CarrierQbePolicy
  include RecordChange
  
  after_create :inherit_policy_coverages, if: -> { policy_type&.designation == 'MASTER-COVERAGE' }
  after_create :schedule_coverage_reminders, if: -> { policy_type&.designation == 'MASTER-COVERAGE' }
  
  after_save :start_automatic_master_coverage_policy_issue, if: -> { policy_type&.designation == 'MASTER' }
  
  belongs_to :agency, optional: true
  belongs_to :account, optional: true
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
  
  has_many :policy_coverages, autosave: true
  has_many :coverages, -> { where(enabled: true) },
  class_name: 'PolicyCoverage'
  
  has_many :policy_premiums, autosave: true
  # has_one :premium, -> { find_by(enabled: true) }, class_name: 'PolicyPremium'
  
  has_many :invoices, through: :policy_quotes
  
  has_many :charges, through: :invoices
  
  has_many :refunds, through: :charges
  
  has_many :commission_deductions
  
  has_many :histories, as: :recordable
  
  has_many_attached :documents
  
  scope :current, -> { where(status: %i[BOUND BOUND_WITH_WARNING]) }
  scope :policy_in_system, ->(policy_in_system) { where(policy_in_system: policy_in_system) }
  scope :unpaid, -> { where(billing_status: ['BEHIND', 'REJECTED']) }
  
  accepts_nested_attributes_for :policy_coverages, :policy_premiums,
  :insurables, :policy_users, :policy_insurables
  
  #  after_save :update_leases, if: :saved_changes_to_status?
  
  validate :correct_document_mime_type
  validate :is_allowed_to_update?, on: :update
  validate :residential_account_present
  validate :same_agency_as_account
  validate :status_allowed
  validate :carrier_agency
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
    
  enum cancellation_reason: {
    nonpayment:                 0,    # QBE AP
    agent_request:              1,    # QBE AR
    insured_request:            2,    # QBE IR
    new_application_nonpayment: 3,    # QBE NP
    underwriter_cancellation:   4     # QBE UW
  }
  
  
  
  
  
  
  
      
  def in_system?
    policy_in_system == true
  end
      
  def premium
    policy_premiums.where(enabled: true).take
  end
      
  # PolicyApplication.primary_insurable
      
  def primary_insurable
    policy_insurable = policy_insurables.where(primary: true).take
    policy_insurable&.insurable	
  end
  
  def is_allowed_to_update?
    errors.add(:policy_in_system, 'Cannot update in system policy') if policy_in_system == true
  end
  
  def residential_account_present    
    errors.add(:account, 'Account must be specified') if ![4,5].include?(policy_type_id) && account.nil? 
  end
  
  def same_agency_as_account
    return unless in_system?
    
    if ![4,5].include?(policy_type_id)
      errors.add(:account, 'policy must belong to the same agency as account') if agency != account&.agency
    end
  end
  
  def carrier_agency
    return unless in_system?

    errors.add(:carrier, 'carrier agency must exist') unless agency&.carriers&.include?(carrier)
  end
  
  def master_policy
    errors.add(:policy, 'must belong to BOUND Policy Coverage') unless policy&.policy_type&.master_policy? && policy&.BOUND?
  end
  
  def inherit_policy_coverages
    policy_coverages << policy&.policy_coverages
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
        errors.add(:status, 'must have at least one paid invoice to change status')
      end
    end
  end
  
  def premium
    return policy_premiums.order("created_at").last  
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
      { error: 'No policy issue for QBE Specialty' }
    when 'crum'
      crum_issue_policy
    else
      { error: 'Error happened with policy issue' }
    end
  end
  
    enum cancellation_reason: {
    nonpayment:                 0,    # QBE AP
    agent_request:              1,    # QBE AR
    insured_request:            2,    # QBE IR
    new_application_nonpayment: 3,    # QBE NP
    underwriter_cancellation:   4     # QBE UW
  }
  
  EARLY_REFUNDABLE_CANCELLATION_REASONS = ['insured_request']
  
  # Cancels a policy; returns nil if no errors, otherwise a string explaining the error
  def cancel(reason, cancel_date = Time.current.to_date)
    # Handle reason
    return "Cancellation reason is invalid" unless self.class.cancellation_reasons.has_key?(reason)
    # Slaughter the invoices
    max_days_for_full_refund = (CarrierPolicyType.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_id).take&.max_days_for_full_refund || 30).days
    effective_cancel_date = EARLY_REFUNDABLE_CANCELLATION_REASONS.include?(reason) ?
      ((self.created_at + max_days_for_full_refund >= cancel_date) ? self.created_at - 2.days : cancel_date)
      : cancel_date
    self.invoices.each do |invoice|
      invoice.apply_proration(effective_cancel_date, refund_date: effective_cancel_date) # we pass refund_date too just in case someone uses the 'complete_refund_x' refundabilities one day
    end
    # Mark cancelled
    update_columns(status: 'CANCELLED', cancellation_reason: reason, cancellation_date: cancel_date)
    # Unearned balance is the remaining unearned amount on an insurance policy that 
    # needs to be deducted from future commissions to recuperate the loss
    premium&.reload
    commision_amount = premium&.commission&.amount || 0
    unearned_premium = premium&.unearned_premium || 0
    balance = (commision_amount * unearned_premium / premium&.base)
    commission_deductions.create(
      unearned_balance: balance, 
      deductee: premium&.commission_strategy&.commissionable
    )
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
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :number, type: :string
    end
  end

  # Recount every month, so we will get monthly invoice
  def master_policy_billing
    billing_started = false

    policy_coverages = policies&.where(policy_type: 3) || ''
    policy_coverages.each_with_index do |index|
      amount = policy_premiums&.take.base
      policy_coverage_number = policies&.where(policy_type: 3).count || 0
      total_amount = amount * policy_coverage_number
      next if total_amount == 0

      due_date = index == 0 ? status_updated_on : policy.effective_date + index.months
      invoice = invoices.new do |inv|
        inv.due_date        = due_date
        inv.available_date  = due_date + available_period
        inv.user            = primary_user
        inv.amount          = amount
      end
      invoice.save
    end
    billing_started
  end

  private
      
    def date_order
      errors.add(:expiration_date, 'expiration date cannot be before effective date.') if expiration_date < effective_date
    end

    def correct_document_mime_type
      documents.each do |document|
        if !document.blob.content_type.starts_with?('image/png', 'image/jpeg', 'image/jpg', 'image/svg',
          'image/gif', 'application/pdf', 'text/plain', 'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'text/comma-separated-values', 'application/vnd.ms-excel'
          )
          errors.add(:documents, 'The document wrong format, only: PDF, DOC, DOCX, XLSX, XLS, CSV, JPG, JPEG, PNG, GIF, SVG, TXT')
        end
      end
    end
end
