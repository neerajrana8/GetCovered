module Reports
  module DetailedRentersInsurance
    class ExpireSoonPoliciesReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        ExpireSoonPoliciesCreate.run!
      end
    end
  end
end
