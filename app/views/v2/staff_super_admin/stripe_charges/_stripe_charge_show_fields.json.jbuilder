json.extract! stripe_charge :amount, :amount_refunded, :created_at, :id,
  :invoice_id, :status, :status_changed_at, :displayable_error,
  :error_info, :description, :stripe_id, :customer_stripe_id, :processed, :invoice_aware
