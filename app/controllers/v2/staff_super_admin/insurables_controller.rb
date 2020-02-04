##
# V2 StaffAgency Insurables Controller
# File: app/controllers/v2/staff_agency/insurables_controller.rb

module V2
  module StaffSuperAdmin
    class InsurablesController < StaffSuperAdminController

      before_action :set_insurable, only: [:show, :coverage_report]

      def index
        super(:@insurables, Insurable.all)
      end

      def show; end

      def coverage_report
        render json: @insurable.coverage_report
      end

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
          id: [ :scalar, :array ],
          title: [ :scalar, :like ],
          permissions: [ :scalar, :array ],
          insurable_type_id: [ :scalar, :array ],
          insurable_id: [ :scalar, :array ],
          account_id: [ :scalar, :array ]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
