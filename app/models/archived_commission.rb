# == Schema Information
#
# Table name: archived_commissions
#
#  id                     :bigint           not null, primary key
#  amount                 :integer
#  deductions             :integer
#  total                  :integer
#  approved               :boolean
#  distributes            :date
#  paid                   :boolean
#  stripe_transaction_id  :string
#  policy_premium_id      :bigint
#  commission_strategy_id :bigint
#  commissionable_type    :string
#  commissionable_id      :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class ArchivedCommission < ApplicationRecord
  belongs_to :policy_premium, class_name: 'ArchivedPolicyPremium', foreign_key: 'policy_premium_id'
  belongs_to :commission_strategy, class_name: 'ArchivedCommissionStrategy', foreign_key: 'commission_id'
  belongs_to :commissionable, polymorphic: true
end
