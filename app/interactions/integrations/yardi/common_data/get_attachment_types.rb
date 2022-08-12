module Integrations
  module Yardi
    module CommonData
      class GetAttachmentTypes < Integrations::Yardi::CommonData::Base
      
        def execute
          super({})
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
