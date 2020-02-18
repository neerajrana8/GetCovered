module Reports
  module DetailedRentersInsurance
    class UncoveredUnitsReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        UncoveredUnitsCreate.run!
      end
    end
  end
end
