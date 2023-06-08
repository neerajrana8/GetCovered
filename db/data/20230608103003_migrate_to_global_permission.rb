# frozen_string_literal: true

class MigrateToGlobalPermission < ActiveRecord::Migration[6.1]
  def up
    # Migrate agencies
    Agency.in_batches.each_record do |agency|
      if agency.parent_agency.present?
        if agency.parent_agency.global_permission
          permissions = agency.parent_agency.global_permission.permissions
        else
          permissions = agency.parent_agency.global_agency_permission&.permissions
        end
      else
        permissions = agency.global_agency_permission&.permissions
      end
      GlobalPermission.create(ownerable: agency, permissions: permissions) if permissions
    end

    # Migrate Account
    Account.in_batches.each_record do |account|
      permissions = account.agency.global_permission&.permissions

      GlobalPermission.create(ownerable: account, permissions: permissions)
    end

    # Migrate Staff
    Staff.in_batches.each_record do |staff|
      next unless staff.organizable.present?
      permissions = staff.organizable.global_permission&.permissions

      StaffRole.create(role: staff.role, global_permission_attributes: {permissions: permissions}, staff: staff, organizable: staff.organizable) if permissions
    end
  end

  def down
    GlobalPermission.destroy_all
  end
end
