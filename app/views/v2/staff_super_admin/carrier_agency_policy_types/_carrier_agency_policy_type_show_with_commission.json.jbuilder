json.partial! "v2/staff_super_admin/carrier_agency_policy_types/carrier_agency_policy_type_show_fields.json.jbuilder",
  carrier_agency_policy_type: carrier_agency_policy_type

json.commission_strategy_percentage_max do
  carrier_agency_policy_type.commission_strategy&.commission_strategy&.percentage ||
  carrier_agency_policy_type.parent_carrier_agency_policy_type&.commission_strategy&.percentage ||
  100
end

json.commission_strategy_percentage_min do
  child_carrier_agency_policy_types(true).map{|capt| capt.commission_strategy&.percentage }.max || 0
end

json.commission_strategy do
  if carrier_agency_policy_type.commission_strategy.present?
    json.partial! "v2/staff_super_admin/commission_strategies/commission_strategy_show_fields.json.jbuilder",
      commission_strategy: carrier_agency_policy_type.commission_strategy
  end
end
