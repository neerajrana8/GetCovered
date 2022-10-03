# == Schema Information
#
# Table name: archived_commission_deductions
#
#  id               :bigint           not null, primary key
#  unearned_balance :integer
#  deductee_type    :string
#  deductee_id      :bigint
#  policy_id        :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class ArchivedCommissionDeduction < ApplicationRecord
  belongs_to :policy
  belongs_to :deductee, polymorphic: true
end
