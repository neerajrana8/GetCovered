class GlobalPermission < ApplicationRecord
  include GlobalPermissions::AvailablePermissions

  belongs_to :ownerable, polymorphic: true
  serialize :permissions, HashSerializer

  validate :subagency_permissions_restrictions, if: -> { ownerable.is_a? Agency and ownerable.parent_agency.present? }

  after_update :update_subagencies_permissions

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
end
