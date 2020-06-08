FactoryBot.define do
  factory :invoice do
    association :invoiceable, factory: :policy
    association :payer, factory: :user
    due_date { 1.day.ago }
    available_date { 1.day.ago }
  end
end
