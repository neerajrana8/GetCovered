class StaffPermission < ApplicationRecord
  belongs_to :global_agency_permission
  belongs_to :staff
end
