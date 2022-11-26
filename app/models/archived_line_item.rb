# == Schema Information
#
# Table name: archived_line_items
#
#  id                      :bigint           not null, primary key
#  title                   :string
#  price                   :integer          default(0)
#  invoice_id              :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  refundability           :integer          not null
#  category                :integer          default("uncategorized"), not null
#  priced_in               :boolean          default(FALSE), not null
#  collected               :integer          default(0), not null
#  proration_reduction     :integer          default(0), not null
#  full_refund_before_date :date
#
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
