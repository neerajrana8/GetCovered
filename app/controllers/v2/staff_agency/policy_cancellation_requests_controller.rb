##
# V2 StaffAgency Change Requests Controller
# File: app/controllers/v2/staff_agency/change_requests_controller.rb

module V2
  module StaffAgency
    class PolicyCancellationRequestsController < StaffAgencyController
      include PolicyCancellationRequestsMethods

      check_privileges %w[requests.refunds requests.cancellations] => %i[approve decline]

      private

      def relation
        super.where(policies: { agency_id: @agency.id })
      end
    end
  end
end
