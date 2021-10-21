module Integrations
  module Yardi
    class Base < ActiveInteraction::Base
      object :integration

      def execute
        response = request
        parse_result(response.body)
      end

      def request
        faraday_connection.post do |req|
          req.headers['Content-Type'] = 'text/xml;charset=utf-8'
          req.headers['Host'] = 'www.yardipcv.com'
          req.headers['SOAPAction'] = soap_action
          req.headers['Content-Length'] = request_template.length.to_s
          req.body = request_template
        end
      end

      def faraday_connection
        Faraday.new(:url => integration.credentials['urls'][type]) do |faraday|
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
