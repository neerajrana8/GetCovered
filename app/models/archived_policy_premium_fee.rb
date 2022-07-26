# == Schema Information
#
# Table name: archived_policy_premium_fees
#
#  id                :bigint           not null, primary key
#  policy_premium_id :bigint
#  fee_id            :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class ArchivedPolicyPremiumFee < ApplicationRecord
  belongs_to :policy_premium, class_name: "ArchivedPolicyPremium", foreign_key: "policy_premium_id"
  belongs_to :fee
end
