json.extract! payment, :id, :status, :amount,
                       :invoice_id, :created_at, :updated_at

json.invoice do
  json.partial! "v2/staff_agency/invoices/invoice_short_full",
    invoice: payment.invoice

end unless payment.invoice.nil?
