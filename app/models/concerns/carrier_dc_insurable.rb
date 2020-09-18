##
# =Direct Current--*cough cough excuse me* DepositChoice--Insurable Functions Concern
# file: +app/models/concerns/carrier_dc_insurable.rb+

module CarrierDcInsurable
  extend ActiveSupport::Concern

  included do
    def dc_carrier_id
      6
    end
    
    
    
  end
end
