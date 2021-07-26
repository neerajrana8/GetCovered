json.partial! 'v2/shared/carrier_agency_policy_types/fields.json.jbuilder',
              carrier_agency_policy_type: carrier_agency_policy_type

if carrier_agency_policy_type.commission_strategy.present?
  json.partial! 'v2/shared/commission_strategies/fields',
                commission_strategy: carrier_agency_policy_type.commission_strategy
end
