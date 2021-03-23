# =DepositChoice Policy Functions Concern
# file: +app/models/concerns/carrier_dc_policy.rb+

module CarrierDcPolicy
  extend ActiveSupport::Concern
  
  included do
    
    # DC Issue Policy
    
    def dc_issue_policy
      return nil # MOOSE WARNING: generate some dox
    end
  end
end
