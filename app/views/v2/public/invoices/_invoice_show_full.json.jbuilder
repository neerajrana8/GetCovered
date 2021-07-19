json.partial! "v2/public/invoices/invoice_show_fields.json.jbuilder",
  invoice: invoice


json.line_items_attributes do
  unless invoice.line_items.nil?
    
    json.array! invoice.sanitized_line_items do |invoice_line_items|
      json.partial! "v2/public/line_items/line_item_show_fields.json.jbuilder",
        line_item: invoice_line_items
    end
  end
end
