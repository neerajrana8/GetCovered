class Commission < ApplicationRecord
  belongs_to :policy_premium
  belongs_to :commission_strategy
  belongs_to :commissionable, polymorphic: true
end
