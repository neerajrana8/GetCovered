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
        
        def action # override action to add the goofy "_Login"
          "GetResidentTransactions_Login"
        end
        
      end
    end
  end
end
