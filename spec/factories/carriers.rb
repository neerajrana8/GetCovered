FactoryBot.define do
  factory :carrier do
    sequence(:title) { |n| "Test carrier number: #{n}" }

    transient do
      policy_types_count { 1 }
    end
    factory :carrier_with_policy_type do
      after(:create) do |carrier, evaluator|
        create_list(:policy_type, evaluator.policy_types_count)
      end
    end
  end
end