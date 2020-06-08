FactoryBot.define do
  factory :policy do
    expiration_date { 1.year.from_now }
    effective_date { 1.day.ago }
    carrier { Carrier.first }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }
  end
end
