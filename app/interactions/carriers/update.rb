module Carriers
  # creates a carrier an all necessary carrier's stuff:
  # - carrier_policy_types - types that are handled by the carrier with params
  # - carrier_policy_type_availabilities - which policy_types available in different states
  class Update < ActiveInteraction::Base
    object :carrier
    hash :update_params, strip: false

    def execute
      ActiveRecord::Base.transaction do
        update_carrier
        if carrier.errors.any?
          errors.merge(carrier.errors)
          return
        end
        update_carrier_agencies
      end
    end

    private

    def update_carrier
      carrier.update(update_params)
    end

    def update_carrier_agencies
      carrier_agency_authorizations =
        CarrierAgencyAuthorization.joins(:carrier_agency).where(carrier_agencies: { carrier_id: carrier.id })
      carrier_agency_authorizations.
        where.not(carrier_agency_authorizations: { policy_type_id: carrier.policy_type_ids }).
        delete_all

      carrier.carrier_policy_types do |carrier_policy_type|
        states = carrier_policy_type.carrier_policy_type_availabilities.where(available: true).pluck(:state)
        carrier_agency_authorizations.
          where(carrier_agency_authorizations: { policy_type_id: carrier_policy_type.policy_type_id, state: states }).
          update_all(available: true)
        carrier_agency_authorizations.
          where(carrier_agency_authorizations: { policy_type_id: carrier_policy_type.policy_type_id }).
          where.not(carrier_agency_authorizations: { state: states }).
          update_all(available: false)
      end
    end
  end
end
