class PolicyRate < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote
  belongs_to :insurable_rate
end
