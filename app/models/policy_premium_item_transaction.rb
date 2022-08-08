# == Schema Information
#
# Table name: policy_premium_item_transactions
#
#  id                         :bigint           not null, primary key
#  pending                    :boolean          default(TRUE), not null
#  create_commission_items_at :datetime         not null
#  amount                     :integer          not null
#  error_info                 :jsonb
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  recipient_type             :string
#  recipient_id               :bigint
#  commissionable_type        :string
#  commissionable_id          :bigint
#  reason_type                :string
#  reason_id                  :bigint
#  policy_premium_item_id     :bigint
#  analytics_category         :integer          default("other"), not null
#
class PolicyPremiumItemTransaction < ApplicationRecord
  include FinanceAnalyticsCategory # provides analytics_category enum

  belongs_to :policy_premium_item
  belongs_to :commissionable,
    polymorphic: true
  belongs_to :recipient,
    polymorphic: true
  belongs_to :reason,
    polymorphic: true

  has_many :policy_premium_item_transaction_memberships
  has_many :commission_items,
    as: :reason
  
  validates_presence_of :amount
  validates_inclusion_of :pending, in: [true, false]
  validates_presence_of :create_commissions_at,
    if: Proc.new{|ppit| ppit.pending }

  def unleash_commission_item!
    return nil if !self.pending
    commission_item = ::CommissionItem.new(
      amount: self.amount,
      commission: ::Commission.collating_commission_for(self.recipient),
      commissionable: self.commissionable,
      reason: self
    )
    begin
      ::ActiveRecord::Base.transaction(requires_new: true) do
        self.lock!
        return nil if !self.pending
        commission_item.commission.lock!
        self.update!(pending: false)
        commission_item.save!
      end
    rescue ::ActiveRecord::RecordInvalid => err
      self.update(error_info: { error_type: "Failed to unleash commission item", record_type: err.class.name, record: error.record.to_json, errors: err.record.errors.to_h })
      return err
    end
    return nil
  end
  
  
  
end
