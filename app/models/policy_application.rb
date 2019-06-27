##
# =Policy Application Model
# file: +app/models/policy_application.rb+

class PolicyApplication < ApplicationRecord  
  
  # Concerns
  include CarrierQbePolicy
  
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
    
  private 
  
    def initialize_policy_application
    	build_fields() if fields.empty?    
    end
    
    def build_fields
	  	carrier_policy_type = CarrierPolicyType.where(carrier: carrier, policy_type: policy_type).take
	  	self.fields = carrier_policy_type.application_fields
	  end
end
