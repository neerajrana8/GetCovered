module Integrations
  module Yardi
    module RentersInsurance
      class GetUnitConfiguration < Integrations::Yardi::RentersInsurance::Base
        string :property_id #getcov00
        def execute
          super(**{
            PropertyId: property_id
          }.compact)
        end
      end
    end
  end
end
