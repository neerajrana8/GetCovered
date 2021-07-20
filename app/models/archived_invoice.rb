class ArchivedInvoice < ApplicationRecord

  belongs_to :invoiceable, polymorphic: true
  belongs_to :payer, polymorphic: true
  
  has_many :charges, class_name: "ArchivedCharge", foreign_key: "invoice_id"
  has_many :refunds, class_name: "ArchivedRefund", foreign_key: "refund_id", through: :charges
  has_many :disputes, class_name: "ArchivedDispute", foreign_key: "dispute_id", through: :charges
  has_many :line_items, class_name: "ArchivedLineItem", foreign_key: "invoice_id"
  has_many :histories, as: :recordable

  enum status: {
    quoted:             0, 
    upcoming:           1,
    available:          2,
    processing:         3,
    complete:           4,
    missed:             5,
    canceled:           6,
    managed_externally: 7
  }
end
