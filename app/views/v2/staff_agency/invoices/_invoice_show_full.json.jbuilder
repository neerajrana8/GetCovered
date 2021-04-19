json.partial! "v2/staff_agency/invoices/invoice_show_fields.json.jbuilder",
  invoice: invoice


json.stripe_charges do
  unless invoice.stripe_charges.nil?
    json.array! invoice.stripe_charges do |invoice_charges|
      json.partial! "v2/staff_agency/stripe_charges/stripe_charge_show_full.json.jbuilder",
        stripe_charge: invoice_charges
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
