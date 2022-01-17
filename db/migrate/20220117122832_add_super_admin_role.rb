class AddSuperAdminRole < ActiveRecord::Migration[6.1]
  def change
    staffs = Staff.where(role: 'super_admin')
    staffs.each do |staff|
      if staff.staff_roles.where(role: 'super_admin').count === 0
        staff.staff_roles.update(primary: false)
        StaffRole.create(staff: staff, role: 'super_admin', primary: true)
      end
    end
  end
end
