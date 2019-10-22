json.partial! "v2/staff_agency/invoices/invoice_show_fields.json.jbuilder",
  invoice: invoice


json.charges do
  unless invoice.charges.nil?
    json.array! invoice.charges do |invoice_charges|
      json.partial! "v2/staff_agency/charges/charge_show_full.json.jbuilder",
        charge: invoice_charges
    end
  end
end

json.line_items_attributes do
  unless invoice.line_items.nil?
    json.array! invoice.line_items do |invoice_line_items|
      json.partial! "v2/staff_agency/line_items/line_item_show_full.json.jbuilder",
        line_item: invoice_line_items
    end
  end
end

json.policy do
  unless invoice.policy.nil?
    json.partial! "v2/staff_agency/policies/policy_short_fields.json.jbuilder",
      policy: invoice.policy
  end
end
