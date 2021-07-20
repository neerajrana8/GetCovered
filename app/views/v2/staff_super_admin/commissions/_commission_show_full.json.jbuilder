json.partial! "v2/staff_super_admin/commissions/commission_show_fields.json.jbuilder",
  commission: commission


json.recipient do
  json.partial! "v2/staff_super_admin/#{commission.recipient.class.name.underscore.pluralize}/#{commission.recipient.class.name.underscore}_short_fields.json.jbuilder",
    *{ commission.recipient.class.name.underscore.to_sym => commission.recipient }
end


json.commission_items do
  json.array! commission.commission_items do |commission_commission_items|
    json.partial! "v2/staff_super_admin/commission_items/commission_item_index_fields.json.jbuilder",
      commission_item: commission_commission_items
  end
end
