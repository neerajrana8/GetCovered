FactoryBot.define do
  factory :insurable do
    sequence :title, &:to_s
    association :insurable_type, factory: :insurable_type
    association :account, factory: :account

    trait :residential_community do
      insurable_type_id { InsurableType::RESIDENTIAL_COMMUNITIES_IDS.first }
    end

    trait :residential_unit do
      insurable_type_id { InsurableType::RESIDENTIAL_UNITS_IDS.first}
    end
  end
end
