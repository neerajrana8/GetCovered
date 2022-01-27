class MakeFirstRoleActive < ActiveRecord::Migration[6.1]
  def change
    # Migrate Staff
    Staff.in_batches.each_record do |staff|
      role = staff.staff_roles.order(:id).first

      role.update(active: true) if role
    end
  end
end
