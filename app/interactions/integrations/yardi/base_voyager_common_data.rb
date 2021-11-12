module Integrations
  module Yardi
    class BaseVoyagerCommonData < Integrations::Yardi::BaseVoyager
      def type
        "common_data"
      end
      
      def xmlns
        'http://tempuri.org/YSI.Interfaces.WebServices/ItfCommonData'
      end
    end
  end
end
