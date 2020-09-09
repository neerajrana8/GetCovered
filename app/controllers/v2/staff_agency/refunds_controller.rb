##
# V2 StaffAgency Refunds Controller
# File: app/controllers/v2/staff_agency/refunds_controller.rb

module V2
  module StaffAgency
    class RefundsController < StaffAgencyController

      include RefundMethods

      before_action :set_refund, only: [:approve, :decline, :update]

    end
  end
end
