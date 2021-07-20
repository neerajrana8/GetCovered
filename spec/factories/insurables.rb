FactoryBot.define do
  factory :insurable do
    sequence :title, &:to_s
    association :account, factory: :account
    enabled { true }
    residential_unit

    trait :residential_community do
      insurable_type_id { InsurableType::RESIDENTIAL_COMMUNITIES_IDS.first }
    end

    trait :residential_unit do
      insurable_type_id { InsurableType::RESIDENTIAL_UNITS_IDS.first }
    end

    trait :building do
      insurable_type_id { InsurableType::BUILDINGS_IDS.first }
    end
  end
end
