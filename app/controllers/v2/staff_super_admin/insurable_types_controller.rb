##
# V2 StaffAgency InsurableTypes Controller
# File: app/controllers/v2/staff_agency/insurable_types_controller.rb

module V2
  module StaffSuperAdmin
    class InsurableTypesController < StaffSuperAdminController
      def index
        super(:@insurable_types, InsurableType)
      end

      private

      def view_path
        super + '/insurable_types'
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = InsurableType
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.insurable_types
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          occupiable: %i[scalar array],
          enabled: %i[scalar array],
          category: %i[scalar array],
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
