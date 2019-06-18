##
# =Carrier Policy Type Model
# file: +app/models/carrier_policy_type.rb+

class CarrierPolicyType < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
  has_many :carrier_policy_type_availabilities
end
