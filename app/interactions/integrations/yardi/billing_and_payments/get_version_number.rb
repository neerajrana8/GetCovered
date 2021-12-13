module Integrations
  module Yardi
    module BillingAndPayments
      class GetVersionNumber < Integrations::Yardi::BillingAndPayments::Base
        def request_template(**params)
          <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <#{self.class.name.demodulize} xmlns="#{self.xmlns}" />
            </soap:Body>
          </soap:Envelope>
          XML
        end
      end
    end
  end
end
