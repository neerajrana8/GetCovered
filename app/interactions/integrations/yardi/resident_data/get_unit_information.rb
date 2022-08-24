module Integrations
  module Yardi
    module ResidentData
      class GetUnitInformation < Integrations::Yardi::ResidentData::Base
        string :property_id
        def execute
          super(**{
            YardiPropertyId: property_id
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
        
        
        def response_has_error?(response_body)
          #.dig("Envelope", "Body", "GetUnitInformationResponse", "GetUnitInformationResult", "UnitInformation", "Property", "Units", "UnitInfo").class == ::Array
          response_body.index("<GetUnitInformationResult><UnitInformation").nil? || super
        end
      end
    end
  end
end
