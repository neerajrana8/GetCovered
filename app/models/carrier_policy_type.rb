class CarrierPolicyType < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
end
