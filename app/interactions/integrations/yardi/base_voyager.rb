module Integrations
  module Yardi
    class BaseVoyager < Integrations::Yardi::Base
      DICTIONARY = {
        'common_data' => 'http://tempuri.org/YSI.Interfaces.WebServices/ItfCommonData',
        'renters_insurance' => 'http://tempuri.org/YSI.Interfaces.WebServices/ItfRentersInsurance30',
        'resident_data' => 'http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData'
      }
      
      def soap_action
        "#{DICTIONARY[self.type]}/#{self.class.name.demodulize}"
      end
      
      def request_template(**params)
        <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <#{self.class.name.demodulize} xmlns="#{DICTIONARY[self.type]}">
              <UserName>#{integration.credentials['voyager']['username']}</UserName>
              <Password>#{integration.credentials['voyager']['password']}</Password>
              <ServerName>#{integration.credentials['voyager']['database_server']}</ServerName>
              <Database>#{integration.credentials['voyager']['database_name']}</Database>
              <Platform>SQL Server</Platform>
              <InterfaceEntity>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:renters_insurance_entity]}</InterfaceEntity>
              <InterfaceLicense>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:renters_insurance_license]}</InterfaceLicense>
              #{params.map{|k,v| "<#{k}>#{v}</#{k}>" }.join("\n      ")}
            </#{self.class.name.demodulize}>
          </soap:Body>
        </soap:Envelope>
        XML
      end
    end
  end
end
