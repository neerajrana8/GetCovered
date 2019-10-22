##
# V2 User Leases Controller
# File: app/controllers/v2/user/leases_controller.rb

module V2
  module User
    class LeasesController < UserController
            
      def index
        if params[:short]
          super(:@leases)
        else
          super(:@leases)
        end
      end
      
      
      private
      
        def view_path
          super + "/leases"
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Lease)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.leases
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
  end # module User
end
