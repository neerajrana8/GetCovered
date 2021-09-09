class ArchivedPolicyPremiumFee < ApplicationRecord
  belongs_to :policy_premium, class_name: "ArchivedPolicyPremium", foreign_key: "policy_premium_id"
  belongs_to :fee
end
