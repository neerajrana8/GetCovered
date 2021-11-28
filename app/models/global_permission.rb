class GlobalPermission < ApplicationRecord
  include GlobalPermissions::AvailablePermissions

  belongs_to :ownerable, polymorphic: true
  serialize :permissions, HashSerializer
end
