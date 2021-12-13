module Integrations
  module Yardi
    module ResidentData
      class Base < Integrations::Yardi::Voyager
        def type
          "resident_data"
        end
        
        def xmlns
          'http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData'
        end
      end
    end
  end
end
