json.array! @invoices,
  partial: 'v2/staff_agency/invoices/invoice_short_full.json.jbuilder',
  as: :invoice
