module Integrations
  module Yardi
    module ResidentData
      class GetTenantDocument < Integrations::Yardi::ResidentData::Base
        string :property_id
        string :resident_id
        string :filename
        
        def execute
          super(**{
            YardiPropertyId: property_id,
            TenantCode: resident_id,
            FileName: filename
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
