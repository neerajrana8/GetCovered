# Lease Type Model
# file: +app/models/address.rb+


class LeaseType < ApplicationRecord
  
  has_many :leases
  
  has_many :lease_type_policy_types
  has_many :policy_types,
    through: :lease_type_policy_types
    
  has_many :lease_type_insurable_types
  has_many :insurable_types,
    through: :lease_type_insurable_types
  
end
