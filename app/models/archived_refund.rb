class ArchivedRefund < ApplicationRecord

  belongs_to :charge, class_name: "ArchivedCharge", foreign_key: "charge_id"
  has_one :invoice, through: :charge, class_name: "ArchivedInvoice", foreign_key: "invoice_id"
  

  enum status: ['processing', 'queued', 'pending', 'succeeded', 'succeeded_via_dispute_payout', 'failed', 'errored', 'failed_and_handled'] # 'failed_and_handled' exists so that we can query for failed or errored refunds and then change their status once they have been issued manually or otherwise taken care of
  enum stripe_status: ['pending', 'succeeded', 'failed', 'canceled'], _prefix: true
  enum stripe_reason: ['duplicate', 'fraudulent', 'requested_by_customer']


end
