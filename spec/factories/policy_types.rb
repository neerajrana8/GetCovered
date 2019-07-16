FactoryBot.define do
  factory :policy_type do
    sequence(:title) { |n| "Test Policy Type ##{n}" }
  end
end