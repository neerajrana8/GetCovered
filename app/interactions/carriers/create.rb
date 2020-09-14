module Carriers
  # creates a carrier an all necessary carrier's stuff:
  # - carrier_policy_types - types that are handled by the carrier with params
  # - carrier_policy_type_availabilities - which policy_types available in different states
  class Create < ActiveInteraction::Base
    hash :carrier_params, strip: false
    array :policy_types_ids, optional: true

    def execute
      carrier = Carrier.create(carrier_params)
      if carrier.errors.any?
        errors.merge!(carrier.errors)
      elsif policy_types_ids.present?
        create_policy_types(carrier)
      end
      carrier
    end

    private

    def create_policy_types(carrier)
      policy_types = PolicyType.find(policy_types_ids)
      policy_types.each do |policy_type|
        carrier_policy_type = CarrierPolicyType.create(carrier_id: carrier.id, policy_type_id: policy_type.id)
        if carrier_policy_type.errors.any?
          errors.merge!(carrier_policy_type.errors)
        else
          create_availabilites(carrier_policy_type)
        end
      end
    end

    def create_availabilites(carrier_policy_type)
      51.times do |state|
        carrier_policy_type_availability =
          CarrierPolicyTypeAvailability.create(state: state, available: false, carrier_policy_type: carrier_policy_type)
        errors.merge!(carrier_policy_type_availability.errors)
      end
    end
  end
end
