##
# =Commission Strategy Model
# file: +app/models/commission_strategy.rb+

class CommissionStrategy < ApplicationRecord

  # Associations
  belongs_to :recipient,
    polymorphic: true
  belongs_to :commission_strategy,
    optional: true
    
  # Validations
  validates :percentage, numericality: { greater_than: 0 }
  validate :percentage_is_sensible
  


  private
  
    def percentage_is_sensible
      self.errors.add(:percentage, "must be 100 if this CommissionStrategy has no parent") if self.commission_strategy.nil? && self.percentage != 100
      self.errors.add(:percentage, "cannot exceed parent's percentage") if !self.commission_strategy.nil? && self.percentage > self.commission_strategy.percentage
    end

end
