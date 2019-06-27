class PolicyQuote < ApplicationRecord  
  
  # Concerns
  include CarrierQbeQuote
  
  belongs_to :policy_application, optional: true
  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true
end
