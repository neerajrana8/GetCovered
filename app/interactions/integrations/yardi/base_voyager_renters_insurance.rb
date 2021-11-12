module Integrations
  module Yardi
    class BaseVoyagerRentersInsurance < Integrations::Yardi::BaseVoyager
      def type
        "renters_insurance"
      end
      
      def xmlns
        "http://tempuri.org/YSI.Interfaces.WebServices/ItfRentersInsurance30"
      end
    end
  end
end
