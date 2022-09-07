# == Schema Information
#
# Table name: commission_strategies
#
#  id                     :bigint           not null, primary key
#  title                  :string           not null
#  percentage             :decimal(5, 2)    not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recipient_type         :string
#  recipient_id           :bigint
#  commission_strategy_id :bigint
#
##
# =Commission Strategy Model
# file: +app/models/commission_strategy.rb+

class CommissionStrategy < ApplicationRecord 

  # Associations
  belongs_to :recipient,
    polymorphic: true
  belongs_to :commission_strategy,
    optional: true
    
  has_many :commission_strategies
  
  # Validations
  validates :percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :percentage_is_sensible,
    if: Proc.new{|cs| cs.will_save_change_to_attribute?('percentage') || cs.will_save_change_to_attribute?('commission_strategy_id') }
  validate :recipient_is_not_commission_strategy
  
  def get_chain(reverse: false)
    tr = [self]
    while !tr.last.commission_strategy.nil?
      tr.push(tr.last.commission_strategy)
    end
    return tr.send(reverse ? :reverse : :itself)
  end

  private
  
    def percentage_is_sensible
      self.errors.add(:percentage, "must be 100 if this CommissionStrategy has no parent") if self.commission_strategy.nil? && self.percentage != 100
      self.errors.add(:percentage, "cannot exceed parent's percentage") if !self.commission_strategy.nil? && self.percentage > self.commission_strategy.percentage
      self.errors.add(:percentage, "cannot be less than child's percentage") if !self.commission_strategy.nil? && self.commission_strategies.any?{|child| child.percentage > self.percentage }
    end
    
    def recipient_is_not_commission_strategy
      # sorry folks, but supporting this would require too much simple logic to be replaced with hellish recursive loops; be veeeery careful if you ever need to add this functionality, stuff uses .recipient with the expectation that it's the REAL, FINAL recipient
      self.errors.add(:recipient, "cannot be a CommissionStrategy") if self.recipient_type == 'CommissionStrategy'
    end

end
