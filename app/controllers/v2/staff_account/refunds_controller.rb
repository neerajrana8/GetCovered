##
# V2 StaffAccount Refunds Controller
# File: app/controllers/v2/staff_account/refunds_controller.rb

module V2
  module StaffAccount
    class RefundsController < StaffAccountController

      include RefundMethods

      before_action :set_refund, only: [:approve, :decline, :update]

    end
  end
end
