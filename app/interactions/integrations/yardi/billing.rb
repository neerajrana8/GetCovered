module Integrations
  module Yardi
    class Billing < Integrations::Yardi::Base
    
      # subclasses should define methods :type and :xmlns
    
      def demodulized
        self.class.name.demodulize
      end
    
      def get_event_process
        "billing_" + self.class.name.demodulize.underscore # we want it to match the calling convention, not necessarily have crap like _Login hanging off of it
      end
    
      def soap_action
        "#{self.xmlns}/#{self.demodulized}"
      end
      
      def request_template(**params)
        <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <#{self.demodulized} xmlns="#{self.xmlns}">
              <UserName>#{integration.credentials['billing']['username']}</UserName>
              <Password>#{integration.credentials['billing']['password']}</Password>
              <ServerName>#{integration.credentials['billing']['database_server']}</ServerName>
              <Database>#{integration.credentials['billing']['database_name']}</Database>
              <Platform>SQL Server</Platform>
              <InterfaceEntity>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:billing_entity]}</InterfaceEntity>
              <InterfaceLicense>#{Rails.application.credentials.yardi[ENV['RAILS_ENV'].to_sym][:billing_license]}</InterfaceLicense>
              #{params.map{|k,v| "<#{k}>#{stringify(v)}</#{k}>" }.join("\n      ")}
            </#{self.demodulized}>
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
