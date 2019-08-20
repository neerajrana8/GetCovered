FactoryBot.define do
  factory :invoice do
    number { '100' }
    association :policy, factory: :policy
    association :user, factory: :user
    due_date { 1.day.ago }
    available_date { 1.day.ago }
  end
end
