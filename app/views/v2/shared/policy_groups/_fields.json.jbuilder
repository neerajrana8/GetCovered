json.extract! policy_group, :id, :number, :effective_date, :expiration_date, :auto_renew, :last_renewed_on,
              :renew_count, :billing_status, :billing_dispute_count, :billing_behind_since,
              :cancellation_reason, :cancellation_date, :status, :status_changed_on, :billing_dispute_status,
              :billing_enabled, :system_purchased, :serviceable, :has_outstanding_refund, :system_data,
              :last_payment_date, :next_payment_date, :policy_in_system, :auto_pay, :agency_id,
              :account_id, :carrier_id, :policy_type_id, :created_at, :updated_at
