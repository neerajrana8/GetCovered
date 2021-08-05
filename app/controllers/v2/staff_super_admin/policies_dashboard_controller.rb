module V2
  module StaffSuperAdmin
    class PoliciesDashboardController < StaffSuperAdminController
      include ::PoliciesDashboardMethods

      private

      def recipient
        Agency.get_covered
      end
    end
  end
end
