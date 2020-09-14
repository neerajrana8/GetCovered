##
# V2 StaffSuperAdmin CarrierPolicyTypeAvailabilities Controller
# File: app/controllers/v2/staff_super_admin/carrier_policy_type_availabilities_controller.rb

module V2
  module StaffSuperAdmin
    class CarrierPolicyTypeAvailabilitiesController < StaffSuperAdminController
      
      before_action :set_carrier_policy_type_availability, only: %i[update show]
      before_action :set_substrate, only: %i[create index]
      
      def index
        super(:@carrier_policy_type_availabilities, @substrate)
      end
      
      def show; end
      
      def create
        if create_allowed?
          @carrier_policy_type_availability = @substrate.new(create_params)
          if @carrier_policy_type_availability.errors.none? && @carrier_policy_type_availability.save
            render :show,
                   status: :created
          else
            render json: @carrier_policy_type_availability.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @carrier_policy_type_availability.update(update_params)
            render :show,
                   status: :ok
          else
            render json: @carrier_policy_type_availability.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      
      private
      
      def view_path
        super + '/carrier_policy_type_availabilities'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def set_carrier_policy_type_availability
        @carrier_policy_type_availability = access_model(::CarrierPolicyTypeAvailability, params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::CarrierPolicyTypeAvailability)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.carrier_policy_type_availabilities
        end
      end
        
      def create_params
        return({}) if params[:carrier_policy_type_availability].blank?

        to_return = params.require(:carrier_policy_type_availability).permit(
          :available, :carrier_policy_type_id, :state,
          zip_code_blacklist: {}
        )
        to_return
      end
        
      def update_params
        return({}) if params[:carrier_policy_type_availability].blank?

        params.require(:carrier_policy_type_availability).permit(
          :available, zip_code_blacklist: {}
        )
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          carrier_policy_type_id: %i[scalar array],
          state: %i[scalar array],
          available: %i[scalar]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
