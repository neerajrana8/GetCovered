FactoryBot.define do
  factory :user do
    sequence(:email) {|n| "test#{n}@test.com" }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    association :profile, factory: :profile
  end
end