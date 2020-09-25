module CarrierPolicyTypeAvailabilities
  class Update < ActiveInteraction::Base
    object :carrier_policy_type_availability
    hash :update_params, strip: false

    delegate :state, :zip_code_blacklist, :policy_type, :available, to: :carrier_policy_type_availability

    def execute
      carrier_policy_type_availability.update(update_params)
      if carrier_policy_type_availability.errors.any?
        errors.merge(carrier_policy_type_availability.errors)
        return
      end
      update_carrier_agency_authorizations
    end

    private

    def update_carrier_agency_authorizations
      carrier_agency_authorizations =
        CarrierAgencyAuthorization.
          joins(:carrier_agency).
          where(carrier_agencies: { carrier_id: carrier_policy_type_availability.carrier.id }).
          where(carrier_agency_authorizations: { state: state, policy_type_id: policy_type.id })
      carrier_agency_authorizations.each do |carrier_agency_authorization|
        updated_blacklist = update_blacklist(carrier_agency_authorization.zip_code_blacklist)
        updated_availability = available ? carrier_agency_authorization.available : false # switch only when to the false
        carrier_agency_authorization.update(available: updated_availability, zip_code_blacklist: updated_blacklist)
      end
    end

    def update_blacklist(authorization_blacklist)
      zip_code_blacklist.each do |key, value|
        if authorization_blacklist[key].nil?
          authorization_blacklist[key] = value
        elsif authorization_blacklist[key].any? && value.any?
          authorization_blacklist[key] |= value
        elsif authorization_blacklist[key].any? && value.empty?
          authorization_blacklist[key] = value
        end
      end
      authorization_blacklist
    end
  end
end
