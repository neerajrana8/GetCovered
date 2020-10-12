##
# V2 StaffAgency Change Requests Controller
# File: app/controllers/v2/staff_agency/change_requests_controller.rb

module V2
  module StaffSuperAdmin
    class PolicyCancellationRequestsController < StaffSuperAdminController
      include PolicyCancellationRequestsMethods

      private

      def relation

        result = params[:agency_id].present? ? super.where(policies: { agency_id: params[:agency_id] }) : super
        result
      end
    end
  end
end
