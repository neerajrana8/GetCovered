FactoryBot.define do
  factory :admin, class: Staff do
    sequence(:email) {|n| "admin#{n}@test.com" }
    uid { email }
    provider { "email" }
    enabled { true }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    role { 'super_admin' }
    profile
  end
end
