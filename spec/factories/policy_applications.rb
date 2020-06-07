FactoryBot.define do
  factory :policy_application do
    expiration_date { 1.day.from_now }
    effective_date { 1.day.ago }
    carrier { Carrier.first }
    policy
    account
    agency
    policy_type { carrier.policy_types.take }
  end
end
