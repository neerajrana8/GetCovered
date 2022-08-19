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
            Attachment: Base64.strict_encode64(attachment.class == ::String ? attachment : attachment.download) + "\n"
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
        
        def camelbase_datacase
          true
        end
        
        def request_template(**params) # we overrode this when debugging; since it works there is no reason to unoverride it. but camelbase_datacase should give us the same result if we used the same format as in the _ext version, we shouldn't need the itf: stuff
          <<~XML
            <soapenv:Envelope
              xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:itf="http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData">
               <soapenv:Header/>
               <soapenv:Body>
                  <itf:ImportTenantLeaseDocumentPDF>
                     #{params.map{|k,v| k.blank? ? stringify(v) : v.class == ::Array ? v.map{|vv| "<itf:#{k}>#{vv}</itf:#{k}>" }.join("") : "<itf:#{k}>#{stringify(v)}</itf:#{k}>" }.join("\n      ")}
                  </itf:ImportTenantLeaseDocumentPDF>
               </soapenv:Body>
            </soapenv:Envelope>
          XML
        end
        
        
      end
    end
  end
end
