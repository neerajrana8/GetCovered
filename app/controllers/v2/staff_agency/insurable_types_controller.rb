##
# V2 StaffAgency InsurableTypes Controller
# File: app/controllers/v2/staff_agency/insurable_types_controller.rb

module V2
  module StaffAgency
    class InsurableTypesController < StaffAgencyController
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@insurable_types, @substrate)
        else
          super(:@insurable_types, @substrate)
        end
      end
      
      def access_model
        model_class
      end
      
      
      private
      
        def view_path
          super + "/insurable_types"
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::InsurableType)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.insurable_types
          end
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
  end # module StaffAgency
end
