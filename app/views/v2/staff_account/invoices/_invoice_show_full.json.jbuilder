json.partial! "v2/staff_account/invoices/invoice_show_fields.json.jbuilder",
  invoice: invoice


json.line_items_attributes do
  unless invoice.line_items.nil?
    json.array! invoice.line_items do |invoice_line_items|
      json.partial! "v2/staff_account/line_items/line_item_show_fields.json.jbuilder",
        line_item: invoice_line_items
    end
  end
end


json.stripe_charges do
  unless invoice.stripe_charges.nil?
    json.array! invoice.stripe_charges do |invoice_charges|
      json.partial! "v2/staff_account/stripe_charges/stripe_charge_show_fields.json.jbuilder",
        stripe_charge: invoice_charges
    end
  end
end


json.refunds do
  unless invoice.refunds.nil?
    json.array! invoice.refunds do |invoice_refunds|
      json.partial! "v2/staff_account/refunds/refund_show_fields.json.builder",
        refund: invoice_refunds
    end
  end
end
