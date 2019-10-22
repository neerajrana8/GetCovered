##
# =Policy Premium Model
# file: +app/models/policy_premium.rb+

class PolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote
  belongs_to :billing_strategy
  
  has_many :policy_premium_fees
  has_many :fees, 
    through: :policy_premium_fees
  
  validate :correct_total

  def application
		return policy_quote.policy_application  
  end
  
  def correct_total
    errors.add(:total, 'incorrect total') if total != base + taxes + total_fees
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
		
		found_fees = regional_availability.fees + billing_strategy.fees
		found_fees.each { |fee| self.fees << fee }
		
	end
	
	def calculate_fees
  	
    self.fees.each do |fee|
      if fee.amount_type == "FLAT"
        if fee.per_payment
          self.total_fees += fee.amount * billing_strategy.new_business["payments"].count { |x| x > 0 }      
        else
          self.total_fees += fee.amount
        end  
      else
        self.total_fees += (fee.amount.to_f / 100) * self.base
      end
    end
    
    save()
  end
  
  def calculate_total
    self.total = self.base + self.taxes + self.total_fees
    save() if self.total > 0
  end
end
