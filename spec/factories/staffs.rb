FactoryBot.define do
  factory :staff do
    sequence(:email) { |n| "test#{n}@test.com" }
    enabled { true }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    association :profile, factory: :profile
  end
end
