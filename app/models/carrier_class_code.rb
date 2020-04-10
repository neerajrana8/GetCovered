class CarrierClassCode < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
  
  validate :one_enabled_class_code_at_a_time
  
  private
  
    def one_enabled_class_code_at_a_time
      if CarrierClassCode.where(class_code: self.class_code, state_code: self.state_code, enabled: true).count > 0
        errors.add(:class_code, "already exists and is enabled for state code")
      end  
    end
end
