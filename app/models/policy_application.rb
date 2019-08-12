##
# =Policy Application Model
# file: +app/models/policy_application.rb+

class PolicyApplication < ApplicationRecord  
  
  # Concerns
  include CarrierQbePolicyApplication, ElasticsearchSearchable
  
  # Active Record Callbacks
  after_initialize :initialize_policy_application
  
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :agency
  belongs_to :account
  belongs_to :policy, optional: true
  
  has_many :addresses,
    as: :addressable,
    autosave: true
  
  has_many :policy_users
  has_many :users,
    through: :policy_users
    
  has_one :primary_policy_user, -> { where(primary: true).take }, 
    class_name: 'PolicyUser'
  has_one :primary_user,
    class_name: 'User',
    through: :primary_policy_user,
    source: :user
    
  has_many :policy_quotes
	
	validates_presence_of :expiration_date, :effective_date
  validate :date_order, 
    unless: Proc.new { |pol| pol.effective_date.nil? or pol.expiration_date.nil? }	
	
  enum status: { STARTED: 0, IN_PROGRESS: 1, COMPLETE: 2, ABANDONED: 3, 
	  						 QUOTE_IN_PROGRESS: 4, QUOTE_FAILED: 5, QUOTED: 6, 
	  						 MORE_REQUIRED: 7, REJECTED: 8 }	
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end

	def quote
		self.send("#{ carrier.integration_designation }_quote") if complete?
		return false if !complete?
	end
    
  private 
  
    def initialize_policy_application
    	build_fields() if fields.empty?    
    end
    
    def build_fields
	  	carrier_policy_type = CarrierPolicyType.where(carrier: carrier, policy_type: policy_type).take
	  	self.fields = carrier_policy_type.application_fields
	  end
	
    def date_order
      if expiration_date < effective_date
        errors.add(:expiration_date, "expiration date cannot be before effective date.")  
      end  
    end	
end
