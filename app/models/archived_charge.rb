class ArchivedCharge < ApplicationRecord
  belongs_to :invoice, class_name: 'ArchivedInvoice', foreign_key: 'invoice_id'
  has_many :refunds, class_name: 'ArchivedRefund', foreign_key: 'charge_id'
  has_many :disputes, class_name: 'ArchivedDispute', foreign_key: 'charge_id'

  enum status: ['processing', 'pending', 'succeeded', 'failed']
  enum payment_method: ['unknown', 'card', 'bank_account', 'account_credit']
  enum refund_status: ['not_refunded', 'partially_refunded', 'totally_refunded']
end
