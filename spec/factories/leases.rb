FactoryBot.define do
  factory :lease do
    association :account, factory: :account
    association :insurable, factory: :insurable
    association :lease_type, factory: :lease_type
    start_date { 10.day.ago }
    end_date { Time.now }
  end
end
