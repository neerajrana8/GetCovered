##
# V2 StaffAgency Carriers Controller
# File: app/controllers/v2/staff_agency/carriers_controller.rb

module V2
  module StaffAgency
    class CarriersController < StaffAgencyController
      
      before_action :set_carrier,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@carriers, @substrate)
        else
          super(:@carriers, @substrate)
        end
      end
      
      def show
      end

      def add_fees
        agency = Agency.find_by(id: params[:ownerable_id])
        billing_strategy = BillingStrategy.find_by(id: params[:assignable_id])
        if Fee.where(ownerable_id: agency.id, assignable_id: billing_strategy.id).exists?
          render json: { message: 'Already exists' }, status: :unprocessable_entity
        elsif !Fee.where(ownerable_id: agency.id, assignable_id: billing_strategy.id).exists?
          fee = Fee.new(fee_params.merge(ownerable: agency, assignable: billing_strategy))
          fee.save
          render json: { message: 'Fee was succesfully created' }, status: :ok
        else
          render json: { message: 'Fee was not created' }, status: :unprocessable_entity
        end
      end

      def billing_strategies_list
        if params[:carrier_agency_id].present?
          billing_strategies = paginator(BillingStrategy.where(carrier_id: params[:id], agency_id: params[:carrier_agency_id]).order(created_at: :desc))
          render json: billing_strategies, status: :ok
        end
      end

      def fees_list
        if params[:carrier_agency_id].present?
          fees = paginator(Fee.where(ownerable_type: 'Agency', ownerable_id: params[:carrier_agency_id]).order(created_at: :desc))
          render json: fees, status: :ok
        end
      end

      def toggle_billing_strategy
        billing_strategy = BillingStrategy.find_by(id: params[:billing_strategy_id], carrier_id: params[:id])
        billing_strategy.toggle(:enabled).save
        if billing_strategy.enabled?
          render json: { message: 'Billing strategy is switched on' }, status: :ok
        else
          render json: { message: 'Billing strategy is switched off' }, status: :ok
        end
      end

      private
      
        def view_path
          super + "/carriers"
        end
        
        def set_carrier
          @carrier = access_model(::Carrier, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Carrier)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carriers
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

        def fee_params
          params.permit(:title, :type,
            :per_payment, :amortize,
            :amount, :enabled, :amount_type,
            :ownerable_id, :assignable_id
          )
        end
    end
  end # module StaffAgency
end
