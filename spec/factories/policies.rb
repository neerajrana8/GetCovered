FactoryBot.define do
  factory :policy do
    expiration_date { 1.year.from_now }
    effective_date { 1.day.ago }
    carrier_id { 1 }
    sequence(:number) { |n| "bfd55#{n}fgbd" }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type_id { 1 }

    trait :master do
      policy_type_id { PolicyType::MASTER_ID }
    end

    trait :master_coverage do
      policy_type_id { PolicyType::MASTER_COVERAGE_ID }
    end
  end

  factory :policy_with_user_account, class: Policy do
    expiration_date { 1.year.from_now }
    effective_date { 2.day.ago }
    carrier { Carrier.last }
    sequence(:number) { |n| "add55#{n}fgvv" }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }
    policy_users { [FactoryBot.create(:policy_user_with_account)] }

  end
end
