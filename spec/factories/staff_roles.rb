FactoryBot.define do
  factory :staff_role do
    staff
    add_attribute('role')
    primary { true }

    trait :for_agency do
      association :organizable, factory: :agency
      association :global_permission, factory: [:global_permission, :for_agency]
    end

    trait :for_account do
      association :organizable, factory: :account
      association :global_permission, factory: [:global_permission, :for_account]
    end

    after(:create) do |staff_role|
      ids = staff_role.staff.staff_roles.pluck(:id) - [staff_role.id]
      staff_role.staff.staff_roles.where(id: ids).update(primary: false)
    end
  end
end