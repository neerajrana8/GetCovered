class CreateGlobalAgencyPermissions < ActiveRecord::Migration[5.2]
  def up
    create_table :global_agency_permissions do |t|
      t.jsonb :permissions, default: { }

      t.references :agency, index: true

      t.timestamps
    end

    Agency.all.each do |agency|
      GlobalAgencyPermission.create(
        agency: agency,
        permissions: { 'dashboard.leads': true, 'dashboard.properties': false }
      )
    end
  end

  def down
    drop_table :global_agency_permissions
  end
end
