

class PolicyPremiumItemTransaction < ApplicationRecord

  belongs_to :policy_premium_item
  belongs_to :commissionable,
    polymorphic: true
  belongs_to :recipient,
    polymorphic: true
  belongs_to :reason,
    polymorphic: true,
    optional: true

  has_many :policy_premium_item_transaction_memberships
  has_many :commission_items,
    as: :reason
  
  validates_presence_of :amount
  validates_inclusion_of :pending, in: [true, false]
  validates_presence_of :create_commissions_at,
    if: Proc.new{|ppit| ppit.pending }

  def unleash_commission_item!
    commission_item = ::CommissionItem.new(
      amount: self.amount,
      commission: ::Commission.collating_commission_for(self.recipient),
      commissionable: self.commissionable,
      reason: self
    )
    begin
      ::ActiveRecord::Base.transaction(requires_new: true) do
        self.lock!
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
