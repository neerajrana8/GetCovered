##
# V2 StaffSuperAdmin Carriers Controller
# File: app/controllers/v2/staff_super_admin/carriers_controller.rb

module V2
  module StaffSuperAdmin
    class CarriersController < StaffSuperAdminController
      
      before_action :set_carrier,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@carriers)
        else
          super(:@carriers)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @carrier = @substrate.new(create_params)
          if !@carrier.errors.any? && @carrier.save
            render :show,
              status: :created
          else
            render json: @carrier.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @carrier.update(update_params)
            render :show,
              status: :ok
          else
            render json: @carrier.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/carriers"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
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
        def create_params
          return({}) if params[:carrier].blank?
          to_return = params.require(:carrier).permit(
            :bindable, :call_sign, :enabled, :id,
            :integration_designation, :quotable, :rateable, :syncable,
            :title, :verifiable, settings: {}
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:carrier].blank?
          params.require(:carrier).permit(
            :bindable, :call_sign, :enabled, :id,
            :integration_designation, :quotable, :rateable, :syncable,
            :title, :verifiable, settings: {}
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
  end # module StaffSuperAdmin
end
