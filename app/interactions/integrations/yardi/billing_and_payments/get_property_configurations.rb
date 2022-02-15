module Integrations
  module Yardi
    module BillingAndPayments
      class GetPropertyConfigurations < Integrations::Yardi::BillingAndPayments::Base
        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
