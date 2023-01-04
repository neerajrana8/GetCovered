FactoryBot.define do
  factory :admin, class: Staff do
    sequence(:email) {|n| "admin#{n}@test.com" }
    uid { email }
    provider { "email" }
    enabled { true }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    profile
    after(:create) do |admin|
      FactoryBot.create(:super_admin_role, staff: admin, role: 'super_admin')
    end
  end
end
