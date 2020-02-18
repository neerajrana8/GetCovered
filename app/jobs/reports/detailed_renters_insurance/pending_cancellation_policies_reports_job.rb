module Reports
  module DetailedRentersInsurance
    class PendingCancellationPoliciesReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        PendingCancellationPoliciesCreate.run!
      end
    end
  end
end
