module Integrations
  module Yardi
    module BillingAndPayments
      class GetChargeTypes < Integrations::Yardi::BillingAndPayments::Base
        def action # override action to add the goofy "_Login"
          "GetChargeTypes_Login"
        end
      end
    end
  end
end
