module Integrations
  module Yardi
    module BillingAndPayments
      class Base < Integrations::Yardi::Billing
        def type
          "billing_and_payments"
        end
        
        def xmlns
          "http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentTransactions20"
        end
      end
    end
  end
end
