FactoryBot.define do
  factory :commission_strategy do
    title { 'Get Covered / QBE Residential Commission' }
    association :carrier, factory: :carrier_with_policy_type
  end
end
