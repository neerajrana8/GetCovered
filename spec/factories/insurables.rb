FactoryBot.define do
  factory :insurable do
    title { 'Test title' }
    association :insurable_type, factory: :insurable_type
    association :account, factory: :account
  end
end
