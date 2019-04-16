FactoryBot.define do
  factory :super_admin do
    sequence(:email) {|n| "superadmin-#{n}@getcoveredllc.com" }
    confirmed_at { 1.hour.ago }
    password { 'test1234' }
    password_confirmation { 'test1234' }
  end
end