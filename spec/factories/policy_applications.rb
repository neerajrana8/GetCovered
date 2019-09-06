FactoryBot.define do
  factory :policy_application do
    expiration_date { 1.day.from_now }
    effective_date { 1.day.ago }
    carrier
    policy
    account
    agency
    policy_type
  end
end