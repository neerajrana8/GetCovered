module Integrations
  module Yardi
    class BaseVoyagerResidentData < Integrations::Yardi::BaseVoyager
      def type
        "resident_data"
      end
      
      def xlmns
        'http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData'
      end
    end
  end
end
