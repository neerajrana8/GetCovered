module Integrations
  module Yardi
    module RentersInsurance
      class GetUnitConfiguration < Integrations::Yardi::RentersInsurance::Base
        string :property_id
        def execute
          super(**{
            PropertyId: property_id
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
