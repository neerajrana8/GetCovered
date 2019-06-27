##
# =Policy Application Model
# file: +app/models/policy_application.rb+

class PolicyApplication < ApplicationRecord
  
  # Active Record Callbacks
  after_initialize :initialize_policy_application
  
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :agency
  belongs_to :account
  belongs_to :policy
  
  has_many :addresses,
    as: :addressable,
    autosave: true
    
  private 
  
    def initialize_policy_application
    	build_fields() if fields.empty?    
    end
    
    def build_fields
	  	carrier_policy_type = CarrierPolicyType.where(carrier: carrier, policy_type: policy_type).take
	  	self.fields = carrier_policy_type.application_fields
	  end
end
