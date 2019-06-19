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
        
    end
end
