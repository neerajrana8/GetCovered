module V2
  module StaffAgency
    class PoliciesDashboardController < StaffAgencyController
      include ::PoliciesDashboardMethods

      private

      def recipient
        @agency
      end

      def all_policies
        Policy.not_master.where(agency: @agency)
      end
    end
  end
end
