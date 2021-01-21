class GlobalAgencyPermission < ApplicationRecord
  include GlobalAgencyPermissions::AvailablePermissions

  belongs_to :agency
  has_many :staff_permissions

  after_save :update_staff_permissions

  private

  def update_staff_permissions
    staff_permissions.each do |staff_permission|
      permissions.each do |key, value|
        staff_permission.permissions[key] = false if value == false
      end
      staff_permission.save
    end
  end
end
