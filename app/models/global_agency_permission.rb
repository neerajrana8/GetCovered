# == Schema Information
#
# Table name: global_agency_permissions
#
#  id          :bigint           not null, primary key
#  permissions :jsonb
#  agency_id   :bigint
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class GlobalAgencyPermission < ApplicationRecord
  include GlobalAgencyPermissions::AvailablePermissions

  belongs_to :agency
  has_many :staff_permissions

  after_update :update_staff_permissions
  after_update :update_subagencies_permissions

  validate :subagency_permissions_restrictions, if: -> { agency.parent_agency.present? }

  serialize :permissions, HashSerializer

  private

  def subagency_permissions_restrictions
    parent_agency_permission = agency.parent_agency.global_agency_permission

    permissions.each do |key, value|
      next unless value && !parent_agency_permission.permissions[key]

      errors.add(
        :permissions,
        I18n.t('global_agency_permission_model.cant_be_enabled', translated_key: I18n.t("permissions.#{key}"))
      )
    end
  end

  def update_subagencies_permissions
    agency.agencies.each do |child_agency|
      agency_permissions = child_agency.global_agency_permission

      if agency_permissions.nil?
        GlobalAgencyPermission.create(agency: child_agency, permissions: permissions)
      else
        permissions.each do |key, value|
          agency_permissions.permissions[key] = false if value == false
        end

        agency_permissions.save
      end
    end
  end

  def update_staff_permissions
    staff_permissions.each do |staff_permission|
      permissions.each do |key, value|
        # Sync permissions for agency owners
        staff_permission.permissions[key] = value if staff_permission.staff_id == agency.staff_id

        # Only disable for other stuff
        staff_permission.permissions[key] = false if value == false
      end
      staff_permission.save
    end
  end
end
