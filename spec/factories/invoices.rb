FactoryBot.define do
  factory :invoice do
    association :invoiceable, factory: :policy
    association :payer, factory: :user
    collector_type { "Agency" }
    collector_id { 1 }
    available_date { 1.day.ago }
    due_date { 1.day.from_now }
    external { false }
    status { 'available' }
  end
end
