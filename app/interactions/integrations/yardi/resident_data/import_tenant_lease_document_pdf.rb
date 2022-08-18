module Integrations
  module Yardi
    module ResidentData
      class ImportTenantLeaseDocumentPDF < Integrations::Yardi::ResidentData::Base
        string :property_id
        string :resident_id
        string :attachment
        string :attachment_type
        string :description, default: "GC Verified Policy"
        
        def execute
          super(**{
            PropertyId: property_id,
            TenantCode: resident_id,
            AttachmentType: attachment_type,
            Description: description,
            Attachment: Base64.strict_encode64(attachment)
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
        
        def request_template(**params)
          <<~XML
            <?xml version="1.0" encoding="utf-8"?>
            <soap:Envelope xmlns:itf="http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData"
                           xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
              <soap:Header/>
              <soap:Body>
                <itf:#{self.action} xmlns="#{self.xmlns}">
                  #{params.map{|k,v| k.blank? ? stringify(v) : v.class == ::Array ? v.map{|vv| "<#{k}>#{vv}</#{k}>" }.join("") : "<itf:#{k}>#{stringify(v)}</itf:#{k}>" }.join("\n      ")}
                </itf:#{self.action}>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        
        
        
      end
    end
  end
end
