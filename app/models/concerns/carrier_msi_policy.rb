# =MSI Policy Functions Concern
# file: +app/models/concerns/carrier_msi_policy.rb+

module CarrierMsiPolicy
  extend ActiveSupport::Concern
  
  included do
    
    # MSI Issue Policy
    
    def msi_issue_policy
      return nil # MOOSE WARNING: generate some dox
    end
  end
end
