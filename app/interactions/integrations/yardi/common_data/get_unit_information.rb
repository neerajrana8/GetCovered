module Integrations
  module Yardi
    module CommonData
      class GetUnitInformation < Integrations::Yardi::CommonData::Base
        string :property_id
        def execute
          super(**{
            YardiPropertyId: property_id
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
