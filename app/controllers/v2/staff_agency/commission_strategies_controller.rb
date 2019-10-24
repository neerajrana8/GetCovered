##
# V2 StaffAgency CommissionStrategies Controller
# File: app/controllers/v2/staff_agency/commission_strategies_controller.rb

module V2
  module StaffAgency
    class CommissionStrategiesController < StaffAgencyController
      
      before_action :set_commission_strategy,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@commission_strategies, @substrate)
        else
          super(:@commission_strategies, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @commission_strategy = @substrate.new(create_params)
          if !@commission_strategy.errors.any? && @commission_strategy.save
            render :show,
              status: :created
          else
            render json: @commission_strategy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @commission_strategy.update(update_params)
            render :show,
              status: :ok
          else
            render json: @commission_strategy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/commission_strategies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_commission_strategy
          @commission_strategy = access_model(::CommissionStrategy, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::CommissionStrategy)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.commission_strategies
          end
        end
        
        def create_params
          return({}) if params[:commission_strategy].blank?
          to_return = {}
          return(to_return)
        end
        
        def update_params
          return({}) if params[:commission_strategy].blank?
          to_return = {}
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
