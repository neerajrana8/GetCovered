module Integrations
  module Yardi
    class BaseVoyagerCommonData < Integrations::Yardi::BaseVoyager
      def type
        "common_data"
      end
    end
  end
end
