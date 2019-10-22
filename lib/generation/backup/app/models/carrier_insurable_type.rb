class CarrierInsurableType < ApplicationRecord
  belongs_to :carrier
  belongs_to :insurable_type
end
