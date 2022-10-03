# == Schema Information
#
# Table name: policy_premium_item_commissions
#
#  id                     :bigint           not null, primary key
#  status                 :integer          not null
#  payability             :integer          not null
#  total_expected         :integer          not null
#  total_received         :integer          default(0), not null
#  total_commission       :integer          default(0), not null
#  percentage             :decimal(5, 2)    not null
#  payment_order          :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  policy_premium_item_id :bigint
#  recipient_type         :string
#  recipient_id           :bigint
#  commission_strategy_id :bigint
#
##
# =PolicyPremiumItemCommission Model
# file: +app/models/policy_premium_item_commission.rb+

class PolicyPremiumItemCommission < ApplicationRecord

  # Associations
  belongs_to :policy_premium_item
  belongs_to :recipient,
    polymorphic: true
  has_many :commission_items,
    as: :commissionable
  
  # Validations
  validates_presence_of :status
  validates_presence_of :payability
  validates :total_expected, numericality: { greater_than_or_equal_to: 0 }
  validates :total_received, numericality: { greater_than_or_equal_to: 0 }
  validates :percentage, numericality: { greater_than_or_equal_to: 0 }
  
  # Enums
  enum status: {
    quoted: 0,
    active: 1
  }
  enum payability: {
    internal: 0,
    external: 1
  }
  
  # Public Instance Methods
  
  def payable?
    return(self.payability == 'internal' && self.status == 'active')
  end
  
  # sort ourselves in the order in which funds should be distributed (smallest % to greatest)
  def <=>(other)
    tr = (self.payment_order <=> other.payment_order)
    return tr unless tr == 0
    tr = (self.percentage <=> other.percentage)
    return tr unless tr == 0
    return (self.id <=> other.id) # we create from child CommissionStrategy to parent CommissionStrategy, so use the creation order if we can't determine things by payment_order or percentage
  end

end
