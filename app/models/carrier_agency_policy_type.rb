##
# CarrierAgencyPolicyType Model
# file: +app/models/carrier_agency_policy_type.rb+

class CarrierAgencyPolicyType < ApplicationRecord
  belongs_to :carrier
  belongs_to :agency
  belongs_to :policy_type
  belongs_to :commission_strategy,
    optional: true # for now
  
  has_one :carrier_agency, ->(capt) { where(agency_id: capt.agency_id, carrier_id: capt.carrier_id) }
  has_one :carrier_policy_type, ->(capt) { where(policy_type_id: capt.policy_type_id, carrier_id: capt.carrier_id) }
end
