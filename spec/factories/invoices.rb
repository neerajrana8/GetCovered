FactoryBot.define do
  factory :invoice do
    association :policy, factory: :policy
    association :user, factory: :user
    due_date { 1.day.ago }
    available_date { 1.day.ago }
  end
end
