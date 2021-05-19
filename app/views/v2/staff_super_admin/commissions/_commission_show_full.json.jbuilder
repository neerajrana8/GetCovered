json.partial! "v2/staff_super_admin/commissions/commission_show_fields.json.jbuilder",
  commission: commission


json.commission_items do
  json.array! commission.commission_items do |commission_commission_items|
    json.partial! "v2/staff_super_admin/commission_items/commission_item_index_fields.json.jbuilder",
      commission_item: commission_commission_items
  end
end
