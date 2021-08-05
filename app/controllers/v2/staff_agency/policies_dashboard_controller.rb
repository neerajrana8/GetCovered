module V2
  module StaffAgency
    class PoliciesDashboardController < StaffAgencyController
      include ::PoliciesDashboardMethods
      
      def recipient
        @agency
      end
    end
  end
end
