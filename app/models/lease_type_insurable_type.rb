class LeaseTypeInsurableType < ApplicationRecord
  belongs_to :lease_type
  belongs_to :insurable_type
end
