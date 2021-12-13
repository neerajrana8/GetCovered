module Integrations
  module Yardi
    module RentersInsurance
      class GetPropertyList < Integrations::Yardi::RentersInsurance::Base
        string :property_id
        def execute; super(YardiPropertyId: property_id); end
      end
    end
  end
end
