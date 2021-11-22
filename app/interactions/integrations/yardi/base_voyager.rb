module Integrations
  module Yardi
    class BaseVoyager < Integrations::Yardi::Base
    
      # subclasses should define methods :type and :xmlns
    
      def get_event_process
        self.class.name.demodulize.underscore
      end
    
      def soap_action
        "#{self.xmlns}/#{self.class.name.demodulize}"
      end
      
      def request_template(**params)
        <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <#{self.class.name.demodulize} xmlns="#{self.xmlns}">
              <UserName>#{integration.credentials['voyager']['username']}</UserName>
              <Password>#{integration.credentials['voyager']['password']}</Password>
              <ServerName>#{integration.credentials['voyager']['database_server']}</ServerName>
              <Database>#{integration.credentials['voyager']['database_name']}</Database>
              <Platform>SQL Server</Platform>
              <InterfaceEntity>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:renters_insurance_entity]}</InterfaceEntity>
              <InterfaceLicense>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:renters_insurance_license]}</InterfaceLicense>
              #{params.map{|k,v| "<#{k}>#{stringify(v)}</#{k}>" }.join("\n      ")}
            </#{self.class.name.demodulize}>
          </soap:Body>
        </soap:Envelope>
        XML
      end
      
      def stringify(val)
        val.to_s
      end
      
      # useful for little derived buddies
      def xml_block(tag, value)
        value.nil? ? "<#{tag} />" : "<#{tag}>#{value}</#{tag}>"
      end
      
    end
  end
end
