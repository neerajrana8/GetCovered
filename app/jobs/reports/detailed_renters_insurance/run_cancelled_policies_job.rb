module Reports
  module DetailedRentersInsurance
    class RunCancelledPoliciesJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        CancelledPolicies.run!
      end
    end
  end
end
