FactoryBot.define do
  factory :coverage_requirement do
    designation { "MyString" }
    amount { 1 }
    start_date { "2022-11-19" }
    insurable { nil }
  end
end
