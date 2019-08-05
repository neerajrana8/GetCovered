FactoryBot.define do
  factory :policy_user do
    primary { true }
    association :user, factory: :user
  end
end