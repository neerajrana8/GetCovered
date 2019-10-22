json.array! @invoices,
  partial: 'v2/user/invoices/invoice_short_full.json.jbuilder',
  as: :invoice
