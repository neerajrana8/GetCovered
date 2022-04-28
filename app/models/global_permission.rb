class GlobalPermission < ApplicationRecord
  include GlobalPermissions::AvailablePermissions

  belongs_to :ownerable, polymorphic: true
  serialize :permissions, HashSerializer

  validate :subagency_permissions_restrictions, if: -> { ownerable.is_a? Agency and ownerable.parent_agency.present? }
  validate :staff_permissions_restrictions, if: -> { ownerable.is_a? StaffRole }
  validate :account_permissions_restrictions, if: -> { ownerable.is_a? Account }

  after_update :update_subagencies_permissions
  after_update :update_staff_permissions
  after_update :update_subaccounts_permissions

  private

  def subagency_permissions_restrictions
    parent_agency_permission = ownerable.parent_agency.global_permission

    permissions.each do |key, value|
      next unless value && !parent_agency_permission.permissions[key]

      errors.add(
        :permissions,
        I18n.t('global_agency_permission_model.cant_be_enabled', translated_key: I18n.t("permissions.#{key}"))
      )
    end
  end

  def update_subagencies_permissions
    if ownerable.is_a? Agency
      ownerable.agencies.each do |child_agency|
        agency_permissions = child_agency.global_permission

        if agency_permissions.nil?
          GlobalPermission.create(ownerable: child_agency, permissions: permissions)
        else
          permissions.each do |key, value|
            agency_permissions.permissions[key] = false if value == false
          end

          agency_permissions.save
        end
      end
    end
  end

  def staff_permissions_restrictions
    unless ownerable.super_admin? or ownerable.policy_support?
      permissions.each do |key, value|
        # Get global permission from staff's agency
        global_permission = ownerable.organizable.global_permission
        next unless value && !global_permission&.permissions&.[](key)

        errors.add(
          :permissions,
          I18n.t('staff_permission_model.cant_be_enabled', translated_key: I18n.t("permissions.#{key}"))
        )
      end
    end
  end

  def update_staff_permissions
    # Update staff permissions if agency permissions change
    if ownerable.is_a? Agency or ownerable.is_a? Account
      ownerable.staffs.each do |staff|
        staff_role = staff.staff_roles.where(organizable_id: ownerable_id, organizable_type: ownerable_type).last
        staff_permission = staff_role.global_permission

        if staff_permission.nil?
          GlobalPermission.create(ownerable: staff_role, permissions: permissions)
        else
          permissions.each do |key, value|
            # Sync permissions for agency owners
            staff_permission.permissions[key] = value if staff_permission.ownerable_id == ownerable.staff_id

            # Only disable for other stuff
            staff_permission.permissions[key] = false if value == false
          end
          staff_permission.save
        end
      end
    end
  end

  def account_permissions_restrictions
    parent_agency_permission = ownerable.agency.global_permission

    permissions.each do |key, value|
      next unless value && !parent_agency_permission.permissions[key]

      errors.add(
        :permissions,
        I18n.t('global_agency_permission_model.cant_be_enabled', translated_key: I18n.t("permissions.#{key}"))
      )
    end
  end

  def update_subaccounts_permissions
    if ownerable.is_a? Agency
      ownerable.accounts.each do |child_account|
        account_permissions = child_account.global_permission

        if account_permissions.nil?
          GlobalPermission.create(ownerable: child_account, permissions: permissions)
        else
          permissions.each do |key, value|
            account_permissions.permissions[key] = false if value == false
          end

          account_permissions.save
        end
      end
    end
  end
end
