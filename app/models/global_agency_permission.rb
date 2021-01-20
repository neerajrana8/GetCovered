class GlobalAgencyPermission < ApplicationRecord
  include GlobalAgencyPermissions::AvailablePermissions

  belongs_to :agency
  has_many :staff_permissions
end
