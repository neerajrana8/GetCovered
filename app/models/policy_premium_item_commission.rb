##
# =PolicyPremiumItemCommission Model
# file: +app/models/policy_premium_item_commission.rb+

class PolicyPremiumItemCommission < ApplicationRecord

  # Associations
  belongs_to :policy_premium_item
  belongs_to :recipient,
    polymorphic: true
  
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
  
  # sort ourselves in the order in which funds should be distributed (smallest % to greatest)
  def <=>(other)
    tr = (self.percentage <=> other.percentage)
    return tr unless tr == 0
    return (self.id <=> other.id) # we create from child CommissionStrategy to parent CommissionStrategy, so use the creation order if we can't determine things by percentage
  end

end
