module Integrations
  module Yardi
    class GetUnitConfiguration < Integrations::Yardi::BaseVoyagerRentersInsurance
      string :property_id #getcov00
      def execute
        super(**{
          PropertyId: property_id
        }.compact)
      end
    end
  end
end
