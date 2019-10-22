##
# V2 StaffSuperAdmin CarrierAgencies Controller
# File: app/controllers/v2/staff_super_admin/carrier_agencies_controller.rb

module V2
  module StaffSuperAdmin
    class CarrierAgenciesController < StaffSuperAdminController
      
      before_action :set_carrier_agency,
        only: [:update, :destroy]
            
      before_action :set_substrate,
        only: [:create]
      
      def create
        if create_allowed?
          @carrier_agency = @substrate.new(create_params)
          if !@carrier_agency.errors.any? && @carrier_agency.save
            render json: { success: true },
              status: :created
          else
            render json: @carrier_agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @carrier_agency.update(update_params)
            render json: { success: true },
              status: :ok
          else
            render json: @carrier_agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @carrier_agency.destroy
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
          super + "/carrier_agencies"
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
        
        def set_carrier_agency
          @carrier_agency = access_model(::CarrierAgency, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::CarrierAgency)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carrier_agencies
          end
        end
        def create_params
          return({}) if params[:carrier_agency].blank?
          to_return = params.require(:carrier_agency).permit(
            :agency_id, :carrier_id, :created_at, :id
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:carrier_agency].blank?
          params.require(:carrier_agency).permit(
            :created_at, :id
          )
        end
        
    end
  end # module StaffSuperAdmin
end
