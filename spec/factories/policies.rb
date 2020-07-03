FactoryBot.define do
  factory :policy do
    expiration_date { 1.year.from_now }
    effective_date { 1.day.ago }
    carrier { Carrier.first }
    sequence(:number) { |n| "bfd55#{n}fgbd" }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }

    trait :master do
      policy_type_id { PolicyType::MASTER_ID }
    end
  end
end
