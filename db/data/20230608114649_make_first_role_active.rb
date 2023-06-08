# frozen_string_literal: true

class MakeFirstRoleActive < ActiveRecord::Migration[6.1]
  def up
    Staff.in_batches.each_record do |staff|
      role = staff.staff_roles.order(:id).first

      role.update(active: true) if role
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
