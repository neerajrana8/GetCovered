# == Schema Information
#
# Table name: policy_premia
#
#  id                         :bigint           not null, primary key
#  total_premium              :integer          default(0), not null
#  total_fee                  :integer          default(0), not null
#  total_tax                  :integer          default(0), not null
#  total                      :integer          default(0), not null
#  prorated                   :boolean          default(FALSE), not null
#  prorated_last_moment       :datetime
#  prorated_first_moment      :datetime
#  force_no_refunds           :boolean          default(FALSE), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  error_info                 :string
#  policy_quote_id            :bigint
#  policy_id                  :bigint
#  commission_strategy_id     :bigint
#  archived_policy_premium_id :bigint
#  total_hidden_fee           :integer          default(0), not null
#  total_hidden_tax           :integer          default(0), not null
#
FactoryBot.define do
  factory :policy_premium do
    policy
  end
end
