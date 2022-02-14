module Integrations
  module Yardi
    module RentersInsurance
      class GetPropertyList < Integrations::Yardi::RentersInsurance::Base
        string :property_id
        def execute; super(YardiPropertyId: property_id); end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
