module Integrations
  module Yardi
    class GetPropertyConfigurations < Integrations::Yardi::Voyager
      def type; 'renters_insurance'; end # RII docs have this; CDI docs have 'resident_data'; both versions work...
    end
  end
end
