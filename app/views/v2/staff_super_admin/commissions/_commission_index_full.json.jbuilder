json.partial! "v2/staff_super_admin/commissions/commission_index_fields.json.jbuilder",
  commission: commission



json.recipient do
  json.partial! "v2/staff_super_admin/#{commission.recipient.class.name.underscore.pluralize}/#{commission.recipient.class.name.underscore}_short_fields.json.jbuilder",
    *{ commission.recipient.class.name.underscore.to_sym => commission.recipient }
end
