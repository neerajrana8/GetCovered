module Reports
  module DetailedRentersInsurance
    class ActivePoliciesReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        ActivePoliciesCreate.run!
      end
    end
  end
end
