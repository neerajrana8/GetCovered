class CarrierInsurableProfile < ApplicationRecord
  belongs_to :carrier
  belongs_to :insurable
end
