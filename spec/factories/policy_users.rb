FactoryBot.define do
  factory :policy_user do
    primary { true }
    association :user, factory: :user
  end

  factory :policy_user_with_account, class: PolicyUser do
    primary { true }
    status { "accepted" }
    association :user, factory: :user

    trait :set_account_user do
      true
    end

    trait :set_first_as_primary do
      primary { true }
      status { "accepted" }
    end
  end
end
