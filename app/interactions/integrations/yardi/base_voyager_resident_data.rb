module Integrations
  module Yardi
    class BaseVoyagerResidentData < Integrations::Yardi::BaseVoyager
      def type
        "resident_data"
      end
    end
  end
end
