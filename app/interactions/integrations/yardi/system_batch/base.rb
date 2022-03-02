module Integrations
  module Yardi
    module SystemBatch
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
          "system_batch"
        end
        
        def xmlns
          "http://tempuri.org/YSI.Interfaces.WebServices/ResidentTransactions20_SysBatch"
        end
      
        def get_event_process
          "system_batch__" + super
        end
        
      end
    end
  end
end
