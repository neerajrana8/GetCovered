##
# =Policy Model
# file: +app/models/policy.rb+
#
# All that is evil... the Policy model stalks the application
# with silent precision.  Wreaking havoc on everything and everyone
# who touches it.
#
# - Dylan Gaines
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
  
  # Concerns
  include CarrierQbePolicy,
          CarrierCrumPolicy,
          ElasticsearchSearchable

  belongs_to :agency
  belongs_to :account
  belongs_to :carrier
  belongs_to :policy_type
  # belongs_to :billing_profie
  
  has_many :policy_quotes
  has_one :policy_application
  
  has_many :policy_users
  has_many :users,
    through: :policy_users
    
  has_one :primary_policy_user, -> { where(primary: true).first }, 
    class_name: 'PolicyUser'
  has_one :primary_user,
    class_name: 'User',
    through: :primary_policy_user
  
  has_many :policy_coverages, autosave: true
  has_many :coverages, -> { where(enabled: true) }, class_name: 'PolicyCoverage'
  has_many :policy_premiums, autosave: true
  has_one :premium, -> { where(enabled: true).take }, class_name: 'PolicyPremium'
  
  accepts_nested_attributes_for :policy_coverages, :policy_premiums
	
	validates_presence_of :expiration_date, :effective_date
  validate :date_order, 
    unless: Proc.new { |pol| pol.effective_date.nil? or pol.expiration_date.nil? }	
	
  enum status: { APPLICATION_STARTED: 0, APPLICATION_ABANDONED: 1, APPLICATION_COMPLETE: 2, APPLICATION_REJECTED: 3, 
	  						 QUOTE_IN_PROGRESS: 4, QUOTE_FAILED: 5, QUOTED: 6, QUOTE_REJECTED: 7, QUOTE_ACCEPTED: 8,
	  						 AWAITING_ACH: 9, PAID: 10, BOUND: 11, BOUND_WITH_WARNING: 12, BIND_ERROR: 12, BIND_REJECTED: 13,
	  						 RENEWING: 14, RENEWED: 15, EXPIRED: 16, CANCELLED: 17, REINSTATED: 18, 
	  						 EXTERNAL_UNVERIFIED: 19, EXTERNAL_VERIFIED: 20 }
	
	enum billing_dispute_status: { UNDISPUTED: 0, DISPUTED: 1, AWATING_POSTDISPUTE_PROCESSING: 2, NOT_REQUIRED: 3 }
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :number, type: :text
    end
  end

	private
	
    def date_order
      if expiration_date < effective_date
        errors.add(:expiration_date, "expiration date cannot be before effective date.")  
      end  
    end	
  
end