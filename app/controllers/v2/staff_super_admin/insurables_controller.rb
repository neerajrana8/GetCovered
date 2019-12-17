##
# V2 StaffAgency Insurables Controller
# File: app/controllers/v2/staff_agency/insurables_controller.rb

module V2
  module StaffSuperAdmin
    class InsurablesController < StaffSuperAdminController

      before_action :set_insurable, only: :show

      def index
        super(:@insurables, Insurable.all)
      end

      def show; end

      private

      def view_path
        super + "/insurables"
      end

      def set_insurable
        @insurable = Insurable.find(params[:id])
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
