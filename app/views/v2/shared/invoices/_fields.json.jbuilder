json.extract! invoice, :id, :number, :status, :status_changed, :description, :due_date, :available_date,
              :term_first_date, :term_last_date, :renewal_cycle, :total, :subtotal, :tax, :tax_percent, :system_data,
              :amount_refunded, :amount_to_refund_on_completion, :has_pending_refund, :pending_refund_data, :created_at,
              :updated_at, :invoiceable_type, :invoiceable_id, :proration_reduction, :disputed_charge_count,
              :was_missed, :payer_type, :payer_id
