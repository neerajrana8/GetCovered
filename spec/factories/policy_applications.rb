# == Schema Information
#
# Table name: policy_applications
#
#  id                          :bigint           not null, primary key
#  reference                   :string
#  external_reference          :string
#  effective_date              :date
#  expiration_date             :date
#  status                      :integer          default("started"), not null
#  status_updated_on           :datetime
#  fields                      :jsonb
#  questions                   :jsonb
#  carrier_id                  :bigint
#  policy_type_id              :bigint
#  agency_id                   :bigint
#  account_id                  :bigint
#  policy_id                   :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  billing_strategy_id         :bigint
#  auto_renew                  :boolean          default(TRUE)
#  auto_pay                    :boolean          default(TRUE)
#  policy_application_group_id :bigint
#  coverage_selections         :jsonb            not null
#  extra_settings              :jsonb
#  resolver_info               :jsonb
#  tag_ids                     :bigint           default([]), not null, is an Array
#  tagging_data                :jsonb
#  error_message               :string
#  branding_profile_id         :integer
#  internal_error_message      :string
#
FactoryBot.define do
  factory :policy_application do
    expiration_date { 1.day.from_now }
    effective_date { 1.day.ago }
    carrier { Carrier.first }
    policy
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }
    billing_strategy { FactoryBot.create(:monthly_billing_strategy, agency: agency, carrier: carrier, policy_type: policy_type) }
  end

  factory :policy_application_with_policy, class: PolicyApplication do
    expiration_date { 1.day.from_now }
    effective_date { 1.day.ago }
    carrier { Carrier.first }
    policy { FactoryBot.create(:policy_with_user_account)}
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }
    billing_strategy { FactoryBot.create(:monthly_billing_strategy, agency: agency, carrier: carrier, policy_type: policy_type) }
  end
end
