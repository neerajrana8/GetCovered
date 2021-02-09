class CreateGlobalAgencyPermissions < ActiveRecord::Migration[5.2]
  def up
    create_table :global_agency_permissions do |t|
      t.jsonb :permissions, default: { }

      t.references :agency, index: true

      t.timestamps
    end

    # ensure we do agencies in parent-first order
    done_agency_ids = []
    todo_agencies = ::Agency.where(agency_id: nil)
    while !todo_agencies.blank?
      todo_agencies.each do |agency|
        GlobalAgencyPermission.create(
          agency: agency,
          permissions: GlobalAgencyPermission::AVAILABLE_PERMISSIONS
        )
      end
      done_agency_ids += todo_agencies.map{|agency| agency.id }
      todo_agencies = ::Agency.where(agency_id: done_agency_ids).where.not(id: done_agency_ids)
    end
  end

  def down
    drop_table :global_agency_permissions
  end
end
