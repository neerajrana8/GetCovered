FactoryBot.define do
  factory :policy_coverage do
    enabled { true }
    limit { 10000 }
    deductible { 100 }
  end
end
