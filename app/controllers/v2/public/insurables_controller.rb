##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurablesController < PublicController
      
      before_action :set_insurable,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@insurables, @substrate)
        else
          super(:@insurables, @substrate)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/insurables"
        end
        
        def set_insurable
          @insurable = access_model(::Insurable, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Insurable)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.insurables
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
  end # module Public
end
