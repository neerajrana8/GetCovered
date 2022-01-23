FactoryBot.define do
  factory :global_permission do
    permissions { GlobalPermission::AVAILABLE_PERMISSIONS }

    trait :for_agency do
      association :ownerable, factory: :agency
    end

    trait :for_account do
      association :ownerable, factory: :account
    end

    trait :for_staff_role do
      association :ownerable, factory: :staff_role
    end
  end
end