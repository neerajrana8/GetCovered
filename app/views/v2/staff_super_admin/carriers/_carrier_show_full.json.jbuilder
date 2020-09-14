json.partial! 'v2/staff_super_admin/carriers/carrier_show_fields.json.jbuilder',
              carrier: carrier

json.carrier_policy_types do
  if carrier.carrier_policy_types.any?
    json.array! carrier.carrier_policy_types do |carrier_policy_type|
      json.partial! 'v2/staff_super_admin/carrier_policy_types/carrier_policy_type_show_full.json.jbuilder',
                    carrier_policy_type: carrier_policy_type
    end
  end
end
