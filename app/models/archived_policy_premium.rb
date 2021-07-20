class ArchivedPolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
	belongs_to :billing_strategy, optional: true
	belongs_to :commission_strategy, optional: true, class_name: "ArchivedCommissionStrategy", foreign_key: "commission_strategy_id"
	
	has_one :commission, class_name: "ArchivedCommission", foreign_key: "policy_premium_id"
	
  has_many :policy_premium_fees, class_name: "ArchivedPolicyPremiumFee", foreign_key: "policy_premium_id"
  has_many :fees, 
    through: :policy_premium_fees
    
  def combined_premium(internal: nil)
    return include_special_premium ? self.internal_base + self.internal_special_premium : self.internal_base if internal
		return include_special_premium ? self.base + self.special_premium : self.base  
	end
  
  def calculate_total(persist = false)
    self.total = self.combined_premium() + self.taxes + self.total_fees
    self.carrier_base = self.combined_premium() + self.taxes
    self.calculation_base = self.combined_premium(internal: true) + self.internal_taxes + self.amortized_fees
    save() if self.total > 0 && persist
  end
  
  def internal_fees
    self.amortized_fees + self.deposit_fees
  end
  
  def internal_base
    self.only_fees_internal ? 0 : self.base
  end
  
  def internal_special_premium
    self.only_fees_internal ? 0 : self.special_premium
  end
  
  def internal_taxes
    self.only_fees_internal ? 0 : self.taxes
  end
  
  def internal_total
    self.only_fees_internal ? self.internal_fees : self.total - self.external_fees
  end
  
  
end
