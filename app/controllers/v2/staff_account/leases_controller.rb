##
# V2 StaffAccount Leases Controller
# File: app/controllers/v2/staff_account/leases_controller.rb

module V2
  module StaffAccount
    class LeasesController < StaffAccountController
      
      before_action :set_lease,
        only: [:update, :destroy, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@leases, @substrate)
        else
          super(:@leases, @substrate, :account, :insurable, :lease_type)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @lease = @substrate.new(create_params)
          if !@lease.errors.any? && @lease.save
            render :show,
              status: :created
          else
            render json: @lease.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @lease.update(update_params)
            render :show,
              status: :ok
          else
            render json: @lease.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @lease.destroy
            render json: { success: true },
              status: :ok
          else
            render json: { success: false },
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/leases"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def destroy_allowed?
          true
        end
        
        def set_lease
          @lease = access_model(::Lease, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Lease)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.leases
          end
        end
        
        def create_params
          return({}) if params[:lease].blank?
          to_return = params.require(:lease).permit(
            :covered, :end_date, :insurable_id, :lease_type_id,
            :start_date, :status
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:lease].blank?
          params.require(:lease).permit(
            :covered, :end_date, :start_date, :status
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
  end # module StaffAccount
end
