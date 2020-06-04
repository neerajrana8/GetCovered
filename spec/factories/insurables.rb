FactoryBot.define do
  factory :insurable do
    sequence :title, &:to_s
    association :insurable_type, factory: :insurable_type
    association :account, factory: :account
  end
end
