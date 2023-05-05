module Integrations
  module Yardi
    module ResidentData
      class ImportTenantLeaseDocumentExt < Integrations::Yardi::ResidentData::Base
        string :property_id
        string :resident_id
        object :attachment, class: :Object
        string :attachment_type
        string :file_extension # pdf, xls, xlsx, doc, docx
        string :description, default: "GC Verified Policy"
        object :eventable, class: :Object, default: nil
        
        boolean :debug, default: false
        
        def execute
          super(**{
            (debug ? :YardiPropertyId : :PropertyId) => property_id,
            TenantCode: resident_id,
            AttachmentType: attachment_type,
            Description: description,
            FileExtension: file_extension,
            Attachment: Base64.strict_encode64(attachment.class == ::String ? attachment : attachment.download) + "\n"
          }.compact)
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
        
        def camelbase_datacase
          true
        end
        
        def get_eventable
          return eventable
        end
        
        def special_event_behavior
          :no_body
        end
        
      end
    end
  end
end
