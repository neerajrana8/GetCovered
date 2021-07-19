class ArchivedCommissionStrategy < ApplicationRecord

  belongs_to :commission_strategy, optional: true, class_name: "ArchivedCommissionStrategy", foreign_key: "commission_strategy_id"
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :commissionable, polymorphic: true
  
  enum type: { PERCENT: 0, FLAT: 1 }
  enum override_type: { PERCENT: 0, FLAT: 1 }, _suffix: true
  enum fulfillment_schedule: { MONTHLY: 0, QUARTERLY: 1, ANNUALLY: 2, REAL_TIME: 3 }
  
end
