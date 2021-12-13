module Integrations
  module Yardi
    module RentersInsurance
      class Base < Integrations::Yardi::Voyager
        def type
          "renters_insurance"
        end
        
        def xmlns
          "http://tempuri.org/YSI.Interfaces.WebServices/ItfRentersInsurance30"
        end
      end
    end
  end
end
