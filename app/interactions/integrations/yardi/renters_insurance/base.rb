module Integrations
  module Yardi
    module RentersInsurance
      class Base < Integrations::Yardi::Base
      
        def execute(**params)
          super(**params, **{
            UserName: integration.credentials['voyager']['username'],
            Password: integration.credentials['voyager']['password'],
            ServerName: integration.credentials['voyager']['database_server'],
            Database: integration.credentials['voyager']['database_name'],
            Platform: "SQL Server",
            InterfaceEntity: Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:voyager_entity],
            InterfaceLicense: Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:voyager_license]
          })
        end
        
        def type
          "renters_insurance"
        end
        
        def xmlns
          "http://tempuri.org/YSI.Interfaces.WebServices/ItfRentersInsurance30"
        end
        
        def get_event_process
          "renters_insurance__" + super
        end
        
      end
    end
  end
end
