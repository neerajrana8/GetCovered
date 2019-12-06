class CarrierInsurableProfile < ApplicationRecord
  after_create_commit :set_qbe_id,
    if: Proc.new { |cip| cip.carrier_id == 1 }
    
  belongs_to :carrier
  belongs_to :insurable
  
  private
    def set_qbe_id
      
      return_status = false
      
      if external_carrier_id.nil?
        
        loop do
          self.external_carrier_id = "#{ Rails.application.credentials.qbe[:employee_id] }#{ rand(36**7).to_s(36).upcase }".truncate(8, omission: '')
          return_status = true
          
          break unless CarrierInsurableProfile.exists?(:external_carrier_id => self.external_carrier_id)
        end
      end
      
      update_column(:external_carrier_id, self.external_carrier_id) if return_status == true
      
      return return_status
      
    end  
end
