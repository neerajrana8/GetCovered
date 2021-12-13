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
      end
    end
  end
end
