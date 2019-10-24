##
# V2 StaffAgency Histories Controller
# File: app/controllers/v2/staff_agency/histories_controller.rb

module V2
  module StaffAgency
    class HistoriesController < StaffAgencyController
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@histories, @substrate)
        else
          super(:@histories, @substrate)
        end
      end
      
      
      private
      
        def view_path
          super + "/histories"
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::History)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.histories
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
