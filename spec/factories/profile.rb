FactoryBot.define do
  factory :profile do
    sequence(:first_name) { |n| "first_name_#{n}" }
    sequence(:last_name) { |n| "last_name_#{n}" }
    birth_date { 18.years.ago }
  end
end