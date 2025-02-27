module Integrations
  module Yardi
    class Base < ActiveInteraction::Base
      object :integration
      
      # subclasses are expected to define folk, see the subfolder base.rb classes as examples
      
      ENDPOINT_ENDS = {
        "common_data"=>"itfcommondata.asmx",
        "system_batch"=>"itfresidenttransactions20_sysbatch.asmx",
        "resident_data"=>"itfresidentdata.asmx",
        "renters_insurance"=>"itfrentersinsurance.asmx",
        "billing_and_payments"=>"itfresidenttransactions20.asmx"
      }

      def get_eventable
        nil
      end
      
      def special_event_behavior
        # nil => save the event as expected
        # :no_save => don't save an event
        # :no_body => omit the event body (used for file uploads since it is too large)
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
      
      def retry_request?(prior_attempts, elapsed_seconds)
        false
      end
      
      def response_has_error?(response_body)
        false
      end
      
      # useful for little derived buddies
      def xml_block(tag, value)
        value.nil? ? "<#{tag} />" : value.class == ::Array ? value.map{|v| "<#{tag}>#{v}</#{tag}>" }.join("") : "<#{tag}>#{value}</#{tag}>"
      end

      def request_template(**params)
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <#{self.action} xmlns="#{self.xmlns}">
                #{params.map{|k,v| k.blank? ? stringify(v) : v.class == ::Array ? v.map{|vv| "<#{k}>#{vv}</#{k}>" }.join("") : "<#{k}>#{stringify(v)}</#{k}>" }.join("\n      ")}
              </#{self.action}>
            </soap:Body>
          </soap:Envelope>
        XML
      end
      
      def universal_param_prefix
        nil
      end
      
      def get_endpoint
        if integration.credentials['urls'][type].blank?
          endpoint_end = ENDPOINT_ENDS[type]
          raise StandardError.new("No endpoint has been set for this Yardi call!") if endpoint_end.nil?
          return integration.credentials['urls']['renters_insurance'].downcase.chomp("itfrentersinsurance.asmx") + endpoint_end
        end
        return integration.credentials['urls'][type]
      end
    
      def execute(**params)
        # prepare the event
        request_body = self.request_template(**(universal_param_prefix.nil? ? params : params.transform_keys{|k| "#{universal_param_prefix}#{k.to_s}" }))
        event = Event.new(
          eventable: self.get_eventable || integration,
          verb: 'post',
          format: 'xml',
          interface: 'SOAP',
          process: "yardi__#{self.get_event_process}",
          endpoint: get_endpoint,
          request: special_event_behavior == :no_body ? "(REDACTED FOR EFFICIENCY)" : request_body
        )
        event.save unless special_event_behavior == :no_save
        event.started = Time.now
        # make the call
        true_started = event.started
        attempts = 1
        done_requesting = false
        while !done_requesting
          done_requesting = true
          begin
            result = HTTParty.post(get_endpoint,
              body: request_body,
              headers: {
                'Content-Type' => 'text/xml;charset=utf-8',
                'SOAPAction' => soap_action,
                'Content-Length' => request_body.length.to_s
              },
              ssl_version: :TLSv1_2
            )
          rescue Net::ReadTimeout => e
            if retry_request?(attempts, Time.now - true_started)
              done_requesting = false
              attempts += 1
              event.completed = Time.now
              event.response = "TIMEOUT"
              event.status = 'error'
              event.save unless special_event_behavior == :no_save
              event = event.dup
              event.id = nil # just to be safe and explicit
              event.started = Time.now
            end
          end
        end
        # postprocess the event
        event.completed = Time.now
        event.response = result.response.body
        event.status = (result.code == 200 ? 'success' : 'error')
        if result.code == 200 && (result.response.body.index("Login failed.") || result.response.body.index("Invalid Interface Entity") || response_has_error?(result.response.body))
          event.status = 'error'
        end
        event.save unless special_event_behavior == :no_save
        # all done, broski
        return {
          success: (event.status == 'success'),
          event: event,
          request: result,
          parsed_response: (result.parsed_response || {} rescue {})
        }
      end
    end
    
  end
end
