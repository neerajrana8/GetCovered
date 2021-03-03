module V2
  module StaffSuperAdmin
    class PoliciesDashboardController < StaffSuperAdminController

      before_action :set_policies

      def total

        render 'v2/shared/policies_dashboard/total'
      end

      def graphs

        render 'v2/shared/policies_dashboard/graphs'
      end

      private

      def set_policies
        @policies = Policy.all
      end
    end
  end
end
