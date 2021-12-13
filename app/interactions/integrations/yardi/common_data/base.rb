module Integrations
  module Yardi
    module CommonData
      class Base < Integrations::Yardi::Voyager
        def type
          "common_data"
        end
        
        def xmlns
          'http://tempuri.org/YSI.Interfaces.WebServices/ItfCommonData'
        end
      end
    end
  end
end
