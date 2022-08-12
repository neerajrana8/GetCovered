module Integrations
  module Yardi
    module ResidentData
      class ImportTenantLeaseDocumentExt < Integrations::Yardi::ResidentData::Base
        string :property_id
        string :resident_id
        string :attachment
        string :attachment_type
        string :file_extension # pdf, xls, xlsx, doc, docx
        string :description, default: "GC Verified Policy"
        
        def execute
          super(**{
            PropertyId: property_id,
            TenantCode: resident_id,
            AttachmentType: attachment_type,
            Description: description,
            FileExtension: file_extension,
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
