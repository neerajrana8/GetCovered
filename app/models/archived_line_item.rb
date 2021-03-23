class ArchivedLineItem < ApplicationRecord
  belongs_to :invoice, class_name: "ArchivedInvoice", foreign_key: "invoice_id"

  enum refundability: {
    no_refund: 0,                         # if we cancel, no refund
    prorated_refund: 1                    # if we cancel, prorated refund
  }
  
  enum category: {
    uncategorized: 0,
    base_premium: 1,
    special_premium: 2,
    taxes: 3,
    deposit_fees: 4,
    amortized_fees: 5
  }
  
end
