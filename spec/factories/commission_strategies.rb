FactoryBot.define do
  factory :commission_strategy do
    association :carrier, factory: :carrier_with_policy_type
  end
end
