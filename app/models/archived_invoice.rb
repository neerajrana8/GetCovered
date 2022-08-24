# == Schema Information
#
# Table name: archived_invoices
#
#  id                             :bigint           not null, primary key
#  number                         :string
#  status                         :integer          default("quoted")
#  status_changed                 :datetime
#  description                    :text
#  due_date                       :date
#  available_date                 :date
#  term_first_date                :date
#  term_last_date                 :date
#  renewal_cycle                  :integer          default(0)
#  total                          :integer          default(0)
#  subtotal                       :integer          default(0)
#  tax                            :integer          default(0)
#  tax_percent                    :decimal(5, 2)    default(0.0)
#  system_data                    :jsonb
#  amount_refunded                :integer          default(0)
#  amount_to_refund_on_completion :integer          default(0)
#  has_pending_refund             :boolean          default(FALSE)
#  pending_refund_data            :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  invoiceable_type               :string
#  invoiceable_id                 :bigint
#  proration_reduction            :integer          default(0), not null
#  disputed_charge_count          :integer          default(0), not null
#  was_missed                     :boolean          default(FALSE), not null
#  payer_type                     :string
#  payer_id                       :bigint
#  external                       :boolean          default(FALSE), not null
#
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
