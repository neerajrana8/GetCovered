module Integrations
  module Yardi
    module ResidentData
      class GetAttachmentTypes < Integrations::Yardi::ResidentData::Base
      
        def execute
          super(**{})
        end
                
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
