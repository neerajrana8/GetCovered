module Integrations
  module Yardi
    class Base < ActiveInteraction::Base
      object :integration
      hash :diagnostics, default: {}
      
      # subclasses are expected to define:
      #   request_template
      #   soap_action
      #   get_eventable
      #   get_event_process (leave off the initial "yardi_")
      
      def get_eventable
        nil
      end

      def execute(**params)
        # prepare the event
        request_body = request_template(params)
        event = Event.new(
          eventable: self.get_eventable,
          verb: 'post',
          format: 'xml',
          interface: 'SOAP',
          process: "yardi_#{self.get_event_process}",
          endpoint: integration.credentials['urls'][type],
          request: request_body
        )
        event.save
        event.started = Time.now
        # make the call
        result = HTTParty.post(integration.credentials['urls'][type],
          body: request_template(params),
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
