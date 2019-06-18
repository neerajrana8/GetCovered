class PolicyApplication < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :agency
  belongs_to :account
  belongs_to :policy
end
