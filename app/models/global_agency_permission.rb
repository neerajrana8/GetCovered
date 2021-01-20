class GlobalAgencyPermission < ApplicationRecord
  belongs_to :agency
  has_many :staff_permissions
end
