class LeaseTypePolicyType < ApplicationRecord
  belongs_to :lease_type
  belongs_to :policy_type
end
