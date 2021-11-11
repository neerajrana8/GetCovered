module Integrations
  module Yardi
    class GetPropertyList < Integrations::Yardi::BaseVoyagerCommonData
      string :property_id #getcov00
      def execute; super(YardiPropertyId: property_id); end
    end
  end
end
