module Integrations
  module Yardi
    class Base < ActiveInteraction::Base
      object :integration

      def execute(**params)
        HTTParty.post(integration.credentials['urls'][type],
          body: request_template(params),
          headers: {
            'Content-Type' => 'text/xml;charset=utf-8',
            'Host' => 'www.yardipcv.com',
            'SOAPAction' => soap_action,
            'Content-Length' => request_template.length.to_s
          },
          ssl_version: :TLSv1_2
        )
      end
    end
    
  end
end
