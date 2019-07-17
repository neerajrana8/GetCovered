FactoryBot.define do
  factory :policy do
    expiration_date { 1.year.from_now }
    effective_date { 1.day.ago }
    agency
    account
    association :carrier, factory: :carrier_with_policy_type
    policy_type
  end
end