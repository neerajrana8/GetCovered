class ArchivedDispute < ApplicationRecord
  belongs_to :charge, class_name: "ArchivedCharge", foreign_key: "charge_id"
  has_one :invoice, class_name: "ArchivedInvoice", foreign_key: "invoice_id", through: :charge

  enum status: ['warning_needs_response', 'warning_under_review', 'warning_closed', 'needs_response', 'under_review', 'charge_refunded', 'won', 'lost'] # these are in 1-to-1 correspondence with Stripe's Dispute::status values
  enum reason: ['duplicate', 'fraudulent', 'subscription_canceled', 'product_unacceptable', 'product_not_received', 'unrecognized', 'credit_not_processed', 'general', 'incorrect_account_details', 'insufficient_funds', 'bank_cannot_process', 'debit_not_authorized', 'customer_initiated'] # these are in 1-to-1 correspondence with Stripe's Dispute::reason values
end
