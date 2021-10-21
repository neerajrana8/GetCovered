module Integrations
  module Yardi
    class GetPropertyList < Integrations::Yardi::Base
      def parse_result(result_xml)
        Nokogiri::XML(result_xml)
      end

      def type
        'common_data'
      end

      def soap_action
        'http://tempuri.org/YSI.Interfaces.WebServices/ItfCommonData/GetPropertyList'
      end

      def request_template
        <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <GetPropertyList xmlns="http://tempuri.org/YSI.Interfaces.WebServices/ItfCommonData">
              <UserName>#{integration.credentials['username']}</UserName>
              <Password>#{integration.credentials['password']}</Password>
              <ServerName>#{integration.credentials['database_server']}</ServerName>
              <Database>#{integration.credentials['database_name']}</Database>
              <Platform>SQL Server</Platform>
              <InterfaceEntity>Get Covered Insurance</InterfaceEntity>
              <InterfaceLicense>#{integration.credentials['common_data_license']}</InterfaceLicense>
              <YardiPropertyId>getcov00</YardiPropertyId>
            </GetPropertyList>
          </soap:Body>
        </soap:Envelope>
        XML
      end
    end
  end
end
