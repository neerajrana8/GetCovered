module Integrations
  module Yardi
    class Base < ActiveInteraction::Base
      object :integration
      hash :diagnostics, default: {}, strip: false
      
      # subclasses are expected to define:
      #   get_eventable
      
      def get_eventable
        nil
      end

      def action
        self.class.name.demodulize
      end
    
      def get_event_process
        self.class.name.demodulize.underscore
      end
    
      def soap_action
        "#{self.xmlns}/#{self.action}"
      end
    
      def stringify(val)
        val.to_s
      end
      
      # useful for little derived buddies
      def xml_block(tag, value)
        value.nil? ? "<#{tag} />" : "<#{tag}>#{value}</#{tag}>"
      end

      def request_template(**params)
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <#{self.action} xmlns="#{self.xmlns}">
                #{params.map{|k,v| k.blank? ? stringify(v) : "<#{k}>#{stringify(v)}</#{k}>" }.join("\n      ")}
              </#{self.action}>
            </soap:Body>
          </soap:Envelope>
        XML
      end
    
      def execute(**params)
        # prepare the event
        request_body = self.request_template(**params)
        event = Event.new(
          eventable: self.get_eventable,
          verb: 'post',
          format: 'xml',
          interface: 'SOAP',
          process: "yardi__#{self.get_event_process}",
          endpoint: integration.credentials['urls'][type],
          request: request_body
        )
        event.save
        event.started = Time.now
        # make the call
        result = HTTParty.post(integration.credentials['urls'][type],
          body: request_body,
          headers: {
            'Content-Type' => 'text/xml;charset=utf-8',
            'Host' => 'www.yardipcv.com',
            'SOAPAction' => soap_action,
            'Content-Length' => request_template.length.to_s
          },
          ssl_version: :TLSv1_2
        )
        # postprocess the event
        event.completed = Time.now
        event.response = result.response.body
        event.status = (result.code == 200 ? 'success' : 'error')
        event.save
        # all done, broski
        diagnostics[:event] = event
        diagnostics[:code] = result.code
        return result
      end
    end
    
  end
end
