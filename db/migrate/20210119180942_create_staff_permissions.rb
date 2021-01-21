class CreateStaffPermissions < ActiveRecord::Migration[5.2]
  def up
    create_table :staff_permissions do |t|
      t.jsonb :permissions, default: { }

      t.references :global_agency_permission, index: true
      t.references :staff, index: true

      t.timestamps
    end

    Agency.all.each do |agency|
      agency.staff.each do |staff|
        StaffPermission.create(
          staff: staff,
          global_agency_permission: agency.global_agency_permission,
          permissions: { 'dashboard.leads': true, 'dashboard.properties': true }
        )
      end
    end
  end

  def down
    drop_table :staff_permissions
  end
end
