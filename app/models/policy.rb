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
# +cancellation_code+:: (Integer)
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
  include CarrierCrumPolicy
  include CarrierQbePolicy

  belongs_to :agency
  belongs_to :account
  belongs_to :carrier
  belongs_to :policy_type
  # belongs_to :billing_profie

  has_many :policy_insurables
  has_many :insurables,
    through: :policy_insurables

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
  has_one :premium, -> { find_by(enabled: true) }, class_name: 'PolicyPremium'

  has_many :invoices

  has_many :charges, through: :invoices

  has_many :refunds, through: :charges

  has_many :histories, as: :recordable

  scope :current, -> { where(status: %i[BOUND BOUND_WITH_WARNING]) }
  scope :policy_in_system, ->(policy_in_system) { where(policy_in_system: policy_in_system) }
  scope :unpaid, -> { where(billing_dispute_status: ['BEHIND', 'REJECTED']) }

  accepts_nested_attributes_for :policy_coverages, :policy_premiums,
                                :insurables, :policy_users

  #  after_save :update_leases, if: :saved_changes_to_status?

  validate :same_agency_as_account
  validate :status_allowed
  validate :carrier_agency
  validates_presence_of :expiration_date, :effective_date
  validate :date_order,
    unless: proc { |pol| pol.effective_date.nil? || pol.expiration_date.nil? }

  enum status: { AWAITING_PAYMENT: 0, AWAITING_ACH: 1, PAID: 2, BOUND: 3, BOUND_WITH_WARNING: 4,
                 BIND_ERROR: 5, BIND_REJECTED: 6, RENEWING: 7, RENEWED: 8, EXPIRED: 9, CANCELLED: 10,
                 REINSTATED: 11, EXTERNAL_UNVERIFIED: 12, EXTERNAL_VERIFIED: 13 }

  enum billing_status: { CURRENT: 0, BEHIND: 1, REJECTED: 2, RESCINDED: 3, ERROR: 4, EXTERNAL: 5 }
	
	enum billing_dispute_status: { UNDISPUTED: 0, DISPUTED: 1, AWAITING_POSTDISPUTE_PROCESSING: 2,
		                             NOT_REQUIRED: 3 }
	
  def in_system?
    policy_in_system == true
  end

  	# PolicyApplication.primary_insurable
	
	def primary_insurable
		policy_insurable = policy_insurables.where(primary: true).take
		policy_insurable.insurable	
	end


  # Perform Postdispute Processing
  #
  # Performs all queued refunds after payment disputes have been resolved.
  #
  # Example:
  #   @policy = Policy.find(1)
  #   @policy.perform_postdispute_processing
  #   => nil
  def perform_postdispute_processing
    if in_system?
      refunds.queued.each { |rfnd| rfnd.process(true) }
      with_lock do
        update(billing_dispute_status: 'undisputed') if billing_dispute_status == 'awaiting_postdispute_processing'
      end
    end
  end

  def same_agency_as_account
    errors.add(:account, 'policy must belong to the same agency as account') if agency != account&.agency
  end

  def carrier_agency
    errors.add(:carrier, 'carrier agency must exist') unless agency&.carriers&.include?(carrier)
  end

  def status_allowed
    if in_system?
      if (AWAITING_PAYMENT? || AWAITING_ACH?) && invoices.paid.count.zero?
        errors.add(:status, 'must have at least one paid invoice to change status')
      end
    end
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

  def residential?
    policy_type == PolicyType.residential
  end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :number, type: :text
    end
  end

  private

  def date_order
    errors.add(:expiration_date, 'expiration date cannot be before effective date.') if expiration_date < effective_date
  end
end
