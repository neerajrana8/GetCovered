module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController
      include Leads::LeadsDashboardCalculations
      include Leads::LeadsDashboardMethods

      def set_substrate
        @substrate = Lead.presented.not_archived if @substrate.nil?
      end
    end
  end
end
