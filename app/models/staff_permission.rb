class StaffPermission < ApplicationRecord
  belongs_to :global_agency_permission
  belongs_to :staff

  after_initialize :initialize_staff_permission
  validate :permissions_restrictions
  
  private
  
  def initialize_staff_permission
    self.global_agency_permission ||= staff.organizable&.global_agency_permission
    self.permissions = staff.organizable&.global_agency_permission&.permissions if self.permissions.keys.blank?
    ap self
  end

  def permissions_restrictions
    permissions.each do |key, value|
      next unless value && !global_agency_permission.permissions[key]

      errors.add(
        :permissions,
        I18n.t('staff_permission_model.cant_be_enabled', translated_key: I18n.t("permissions.#{key}"))
      )
    end
  end
end
