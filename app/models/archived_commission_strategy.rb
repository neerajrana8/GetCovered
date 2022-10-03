# == Schema Information
#
# Table name: archived_commission_strategies
#
#  id                     :bigint           not null, primary key
#  title                  :string           not null
#  amount                 :integer          default(10), not null
#  type                   :integer          default("PERCENT"), not null
#  fulfillment_schedule   :integer          default("MONTHLY"), not null
#  amortize               :boolean          default(FALSE), not null
#  per_payment            :boolean          default(FALSE), not null
#  enabled                :boolean          default(FALSE), not null
#  locked                 :boolean          default(FALSE), not null
#  house_override         :integer          default(10), not null
#  override_type          :integer          default("PERCENT"), not null
#  carrier_id             :bigint
#  policy_type_id         :bigint
#  commissionable_type    :string
#  commissionable_id      :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  commission_strategy_id :bigint
#  percentage             :decimal(5, 2)    default(0.0)
#
class ArchivedCommissionStrategy < ApplicationRecord

  belongs_to :commission_strategy, optional: true, class_name: "ArchivedCommissionStrategy", foreign_key: "commission_strategy_id"
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :commissionable, polymorphic: true
  
  enum type: { PERCENT: 0, FLAT: 1 }
  enum override_type: { PERCENT: 0, FLAT: 1 }, _suffix: true
  enum fulfillment_schedule: { MONTHLY: 0, QUARTERLY: 1, ANNUALLY: 2, REAL_TIME: 3 }
  
end
