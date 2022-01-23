FactoryBot.define do
  factory :staff do
    sequence(:email) { |n| "test#{n}@test.com" }
    enabled { true }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    association :profile, factory: :profile
    organizable do
      case role
      when 'agent'
        FactoryBot.create(:agency)
      when 'staff'
        FactoryBot.create(:account)
      end
    end

    after(:create) do |staff|
      # staff.staff_permission ||= FactoryBot.create(:staff_permission, staff: staff) if staff.organizable.is_a?(Agency)
      staff.staff_roles ||= FactoryBot.create(:staff_role, staff: staff, role: staff.role, organizable: staff.organizable)
    end
  end
end
