class MigratePolicySupportRoles < ActiveRecord::Migration[6.1]
  def change
    Staff.where(role: 'policy_support').each do |support|
      StaffRole.create(staff: support, role: 'policy_support', global_permission_attributes: {permissions: {}})
    end
  end
end
