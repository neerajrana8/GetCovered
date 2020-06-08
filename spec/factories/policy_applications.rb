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
end
