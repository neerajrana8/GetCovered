module Integrations
  module Yardi
    module BillingAndPayments
      class GetChargeTypes < Integrations::Yardi::BillingAndPayments::Base
        def action # override action to add the goofy "_Login"
          "GetChargeTypes_Login"
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
