# == Schema Information
#
# Table name: archived_charges
#
#  id                          :bigint           not null, primary key
#  status                      :integer          default("processing")
#  status_information          :string
#  refund_status               :integer          default("not_refunded")
#  payment_method              :integer          default("unknown")
#  amount_returned_via_dispute :integer          default(0)
#  amount_refunded             :integer          default(0)
#  amount_lost_to_disputes     :integer          default(0)
#  amount_in_queued_refunds    :integer          default(0)
#  dispute_count               :integer          default(0)
#  stripe_id                   :string
#  invoice_id                  :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  amount                      :integer          default(0)
#  invoice_update_failed       :boolean          default(FALSE), not null
#  invoice_update_error_call   :string
#  invoice_update_error_record :string
#  invoice_update_error_hash   :jsonb
#
class ArchivedCharge < ApplicationRecord
  belongs_to :invoice, class_name: 'ArchivedInvoice', foreign_key: 'invoice_id'
  has_many :refunds, class_name: 'ArchivedRefund', foreign_key: 'charge_id'
  has_many :disputes, class_name: 'ArchivedDispute', foreign_key: 'charge_id'

  enum status: ['processing', 'pending', 'succeeded', 'failed']
  enum payment_method: ['unknown', 'card', 'bank_account', 'account_credit']
  enum refund_status: ['not_refunded', 'partially_refunded', 'totally_refunded']
end
