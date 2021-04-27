class CommissionItem < ApplicationRecord

  belongs_to :commission
  belongs_to :commissionable,
    polymorphic: true
  belongs_to :reason,
    polymorphic: true
  # for analytics:
  belongs_to :policy_quote,
    optional: true
  belongs_to :policy,
    optional: true

  before_create :set_analytics_fields
  before_create :update_commission_total

  validates_presence_of :amount






  private

    def set_analytics_fields
      self.policy_quote_id = self.commissionable.policy_premium_item.policy_quote&.id if self.policy_quote_id.nil? && self.commissionable_type == 'PolicyPremiumItemCommission'
      self.policy_id = self.commissionable.policy_premium_item.policy_quote&.policy_id if self.policy_id.nil? && self.commissionable_type == 'PolicyPremiumItemCommission'
    end

    def update_commission_total
      self.commission.lock!
      self.commission.update(total: self.commission.total + self.amount)
    end
    
    
    
    
    
    
end
