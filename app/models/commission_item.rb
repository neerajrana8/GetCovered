class CommissionItem < ApplicationRecord

  belongs_to :commission
  belongs_to :commissionable,
    polymorphic: true
  belongs_to :policy,
    optional: true

  before_create :update_commission_total

  validates_presence_of :amount






  private

    def update_commission_total
      self.commission.lock!
      self.commission.update(total: self.commission.total + self.amount)
    end
    
    
    
    
    
    
end
