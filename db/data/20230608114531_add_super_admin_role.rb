# frozen_string_literal: true

class AddSuperAdminRole < ActiveRecord::Migration[6.1]
  def up
    staffs = Staff.where(role: 'super_admin')
    staffs.each do |staff|
      if staff.staff_roles.where(role: 'super_admin').count === 0
        staff.staff_roles.update(primary: false)
        staff_role = StaffRole.create(staff: staff, role: 'super_admin', primary: true)
        GlobalPermission.create(ownerable: staff_role, permissions: GlobalPermission::AVAILABLE_PERMISSIONS)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
