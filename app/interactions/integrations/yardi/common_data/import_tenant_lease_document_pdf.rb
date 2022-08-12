module Integrations
  module Yardi
    module CommonData
      class ImportTenantLeaseDocumentPDF < Integrations::Yardi::CommonData::Base
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
      end
    end
  end
end
