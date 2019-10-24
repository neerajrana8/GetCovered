##
# V2 StaffSuperAdmin Agencies Controller
# File: app/controllers/v2/staff_super_admin/agencies_controller.rb

module V2
  module StaffSuperAdmin
    class AgenciesController < StaffSuperAdminController
      
      before_action :set_agency,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@agencies, @substrate)
        else
          super(:@agencies, @substrate, :agency)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @agency = @substrate.new(create_params)
          if !@agency.errors.any? && @agency.save
            render :show,
              status: :created
          else
            render json: @agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @agency.update(update_params)
            render :show,
              status: :ok
          else
            render json: @agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/agencies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_agency
          @agency = access_model(::Agency, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Agency)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.agencies
          end
        end
        
        def create_params
          return({}) if params[:agency].blank?
          to_return = params.require(:agency).permit(
            :agency_id, :enabled, :staff_id, :title, :tos_accepted,
            :whitelabel, contact_info: {}, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:agency].blank?
          params.require(:agency).permit(
            :enabled, :staff_id, :title, :tos_accepted, :whitelabel,
            contact_info: {}, settings: {}
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
