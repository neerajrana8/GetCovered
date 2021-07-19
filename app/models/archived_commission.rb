class ArchivedCommission < ApplicationRecord
  belongs_to :policy_premium, class_name: 'ArchivedPolicyPremium', foreign_key: 'policy_premium_id'
  belongs_to :commission_strategy, class_name: 'ArchivedCommissionStrategy', foreign_key: 'commission_id'
  belongs_to :commissionable, polymorphic: true
end
