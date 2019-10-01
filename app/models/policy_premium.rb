##
# =Policy Premium Model
# file: +app/models/policy_premium.rb+

class PolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote
  belongs_to :billing_strategy
  
  def application
		return policy_quote.policy_application  
	end
  
  def set_fees
	  # Get CarrierPolicyTypeAvailability Fee for Region
	  # Assumption is made if the policy has gotten this far
	  # It is in an available region
	  carrier_policy_type = application().carrier
	  																	 .carrier_policy_types
	  																	 .where(:policy_type => policy_quote.policy_application.policy_type)
	  																	 .take
	  
	  regional_availability = CarrierPolicyTypeAvailability.where(
		  :state => application().primary_insurable()
		  											 .primary_address().state,
		  :carrier_policy_type => carrier_policy_type
	  ).take
		
		fees = regional_availability.fees + billing_strategy.fees

		pp fees
		
		return fees
	end
end
