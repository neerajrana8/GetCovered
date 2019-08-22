FactoryBot.define do
  factory :policy_application do
    account
    agency
    carrier
    effective_date { 1.day.ago }
    expiration_date { 1.year.from_now }
    policy
    policy_type
  end
end