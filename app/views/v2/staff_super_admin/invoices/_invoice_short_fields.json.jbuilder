json.extract! invoice, :id, :number, :available_date, :due_date, :created_at, :updated_at,
  :external, :status, :status_changed, :under_review, :pending_charge_count, :pending_dispute_count,
  :total_due, :total_payable, :total_reducing, :total_pending, :total_received, :total_undistributable,
  :invoiceable_id, :invoiceable_type,
  :payer_id, :payer_type,
  :collector_id, :collector_type
