json.array! @invoices,
  partial: 'v2/public/invoices/invoice_short_full.json.jbuilder',
  as: :invoice
