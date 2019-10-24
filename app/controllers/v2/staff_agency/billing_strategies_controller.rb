##
# V2 StaffAgency BillingStrategies Controller
# File: app/controllers/v2/staff_agency/billing_strategies_controller.rb

module V2
  module StaffAgency
    class BillingStrategiesController < StaffAgencyController
      
      before_action :set_billing_strategy,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@billing_strategies, @substrate)
        else
          super(:@billing_strategies, @substrate, :agency, :carrier)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @billing_strategy = @substrate.new(create_params)
          if !@billing_strategy.errors.any? && @billing_strategy.save
            render :show,
              status: :created
          else
            render json: @billing_strategy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @billing_strategy.update(update_params)
            render :show,
              status: :ok
          else
            render json: @billing_strategy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/billing_strategies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_billing_strategy
          @billing_strategy = access_model(::BillingStrategy, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::BillingStrategy)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.billing_strategies
          end
        end
        
        def create_params
          return({}) if params[:billing_strategy].blank?
          to_return = params.require(:billing_strategy).permit(
            :carrier_id, :enabled, :policy_type_id, :title,
            new_business: {}, renewal: {}
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:billing_strategy].blank?
          params.require(:billing_strategy).permit(
            :carrier_id, :enabled, :policy_type_id, :title,
            new_business: {}, renewal: {}
          )
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
