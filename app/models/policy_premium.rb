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
		errors.add(:calculation_base, 'incorrect calculation base') if calculation_base != base + taxes + amortized_fees
  end
  
  def set_fees
	  # Get CarrierPolicyTypeAvailability Fee for Region
	  # Assumption is made if the policy has gotten this far
	  # It is in an available region
	  carrier_policy_type = application().carrier
	  																	 .carrier_policy_types
	  																	 .where(:policy_type => policy_quote.policy_application.policy_type)
	  																	 .take
	  
	  state = application().insurables.empty? ? application().fields["premise"][0]["address"]["state"] : 
	                                            application().primary_insurable().primary_address().state
	  
	  regional_availability = CarrierPolicyTypeAvailability.where(
		  :state => state,
		  :carrier_policy_type => carrier_policy_type
	  ).take
		
		found_fees = regional_availability.fees + billing_strategy.fees
		found_fees.each { |fee| self.fees << fee }
		
	end
	
	def calculate_fees(persist = false)
		payments_count = billing_strategy.new_business["payments"]
																		 .count { |x| x > 0 }
		self.fees.each do |fee|
			case fee.amount_type
			when "FLAT"
				if fee.per_payment
					self.amortized_fees += fee.amount * payments_count	
				elsif fee.amortize
					self.amortized_fees += fee.amount.to_f / payments_count
				elsif !fee.per_payment && 
							!fee.amortize
					self.deposit_fees += fee.amount 
				end
			when "PERCENTAGE"
				percentage_amount = (fee.amount.to_f / 100) * self.base
				if fee.per_payment
					self.amortized_fees += percentage_amount * payments_count	
				elsif fee.amortize
					self.amortized_fees += percentage_amount.to_f / payments_count
				elsif !fee.per_payment &&
					 		!fee.amortize
					self.deposit_fees += percentage_amount
				end
			end	
		end 
	  
	  self.total_fees = self.amortized_fees + self.deposit_fees
    
    save() if persist
  end
  
  def calculate_total(persist = false)
    self.total = self.base + self.taxes + self.total_fees
    self.carrier_base = self.base + self.taxes
    self.calculation_base = self.base + self.taxes + self.amortized_fees
    save() if self.total > 0 && persist
  end
end
