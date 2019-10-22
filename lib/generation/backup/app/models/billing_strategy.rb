class BillingStrategy < ApplicationRecord
  
  before_save :check_lock
    
  belongs_to :agency
  belongs_to :carrier
  belongs_to :policy_type
  
  has_many :fees, as: :assignable

  accepts_nested_attributes_for :fees
  
  validate :carrier_accepts_policy_type
  validate :agency_authorized_for_carrier
  
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
      errors.add(:agency, "must be assigned to carrier: #{ carrier.title }") unless carrier.agencies.include?(agency)
    end
end
