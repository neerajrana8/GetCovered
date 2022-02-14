module Integrations
  module Yardi
    module RentersInsurance
      class GetPropertyConfigurations < Integrations::Yardi::RentersInsurance::Base
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
