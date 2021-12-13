module Integrations
  module Yardi
    module BillingAndPayments
      class GetResidentTransactions < Integrations::Yardi::BillingAndPayments::Base
        string :property_id
        
        def execute
          super(**{
            YardiPropertyId: property_id
          }.compact)
        end
        
        def demodulized
          "GetResidentTransactions_Login"
        end
        
      end
    end
  end
end
