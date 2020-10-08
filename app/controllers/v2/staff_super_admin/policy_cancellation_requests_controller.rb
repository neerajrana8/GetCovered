##
# V2 StaffAgency Change Requests Controller
# File: app/controllers/v2/staff_agency/change_requests_controller.rb

module V2
  module StaffSuperAdmin
    class PolicyCancellationRequestsController < StaffSuperAdminController
      include PolicyCancellationRequestsMethods

      private

      def relation
        ChangeRequest.
          joins('INNER JOIN policies ON (change_requests.changeable_id = policies.id AND change_requests.changeable_type = \'Policy\')').
          where(customized_action: 'cancel').
          order(created_at: :desc)
      end
    end
  end
end
