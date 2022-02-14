module Integrations
  module Yardi
    module BillingAndPayments
      class Base < Integrations::Yardi::Base
      
        def execute(**params)
          super(**{
            UserName: integration.credentials['billing']['username'],
            Password: integration.credentials['billing']['password'],
            ServerName: integration.credentials['billing']['database_server'],
            Database: integration.credentials['billing']['database_name'],
            Platform: "SQL Server",
            InterfaceEntity: Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:billing_entity],
            InterfaceLicense: Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:billing_license]
          }, **params)
        end
        
        def type
          "billing_and_payments"
        end
        
        def xmlns
          "http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentTransactions20"
        end
      
        def get_event_process
          "billing_and_payments__" + super
        end
        
      end
    end
  end
end
