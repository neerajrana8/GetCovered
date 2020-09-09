##
# V2 StaffSuperAdmin Refunds Controller
# File: app/controllers/v2/staff_super_admin/refunds_controller.rb

module V2
  module StaffSuperAdmin
    class RefundsController < StaffSuperAdminController

      include RefundMethods

      before_action :set_refund, only: [:approve, :decline, :update]

    end
  end
end
