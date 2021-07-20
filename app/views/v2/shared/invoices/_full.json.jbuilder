json.partial! "v2/shared/invoices/_fields.json.jbuilder",
  invoice: invoice

json.line_items_attributes do
  unless invoice.line_items.nil?
    json.array! invoice.line_items do |invoice_line_items|
      json.partial! "v2/shared/line_items/_fields.json.jbuilder",
        line_item: invoice_line_items
    end
  end
end
