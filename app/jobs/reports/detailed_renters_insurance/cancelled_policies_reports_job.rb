module Reports
  module DetailedRentersInsurance
    class CancelledPoliciesReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        CancelledPoliciesCreate.run!
      end
    end
  end
end
