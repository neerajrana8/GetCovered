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


################################################ MOOSE WARNING: old below!



  # ActiveRecord Callbacks
  
  before_save :check_lock, 
    unless: Proc.new { |cs| cs.locked_changed? && cs.locked_was == false }
  
  # Assocatiations
  
  # Turn off single table inheritance
  self.inheritance_column = :_type_disabled
  
  belongs_to :commission_strategy, optional: true
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :commissionable, polymorphic: true
  
  # Validations
  
  validates_presence_of :title, :type, :fulfillment_schedule, :house_override, :override_type
  validates_inclusion_of :amortize, :per_payment, :enabled, :locked,
    in: [true, false], message: 'cannot be blank'
  validates :amount,
    numericality: { greater_than_or_equal_to: 0 }
  validate :carrier_accepts_policy_type
  validate :agency_authorized_for_carrier,
    if: Proc.new { |cs| cs.commissionable_type == "Agency" }
 
  enum type: { PERCENT: 0, FLAT: 1 }
  enum override_type: { PERCENT: 0, FLAT: 1 }, _suffix: true
  enum fulfillment_schedule: { MONTHLY: 0, QUARTERLY: 1, ANNUALLY: 2, REAL_TIME: 3 }
  
  private
  
    def check_lock
      unless locked? && locked_was == false
        raise ActiveRecord::ReadOnlyRecord if locked?
      end    
    end
    
    def carrier_accepts_policy_type
      errors.add(:policy_type, "must be assigned to carrier: #{ carrier.title }") unless carrier.policy_types.include?(policy_type)
    end
    
    def agency_authorized_for_carrier
      errors.add(:commissionable, "must be assigned to carrier: #{ carrier.title }") unless carrier.agencies.include?(commissionable)
    end
end
