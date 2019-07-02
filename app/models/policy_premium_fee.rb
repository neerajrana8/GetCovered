class PolicyPremiumFee < ApplicationRecord
  belongs_to :policy_premium
  belongs_to :fee
end
