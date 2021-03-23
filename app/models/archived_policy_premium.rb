class ArchivedPolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
	belongs_to :billing_strategy, optional: true
	belongs_to :commission_strategy, optional: true, class_name: "ArchivedCommissionStrategy", foreign_key: "commission_strategy_id"
	
	has_one :commission, class_name: "ArchivedCommission", foreign_key: "policy_premium_id"
	
  has_many :policy_premium_fees, class_name: "ArchivedPolicyPremiumFee", foreign_key: "policy_premium_id"
  has_many :fees, 
    through: :policy_premium_fees
end
