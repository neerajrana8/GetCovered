##
# V2 StaffAccount Insurables Controller
# File: app/controllers/v2/staff_account/insurables_controller.rb

module V2
  module StaffAccount
    class InsurablesController < StaffAccountController
      
      before_action :set_insurable,
        only: [:update, :destroy, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@insurables)
        else
          super(:@insurables)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @insurable = @substrate.new(create_params)
          if !@insurable.errors.any? && @insurable.save
            render :show,
              status: :created
          else
            render json: @insurable.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @insurable.update(update_params)
            render :show,
              status: :ok
          else
            render json: @insurable.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @insurable.destroy
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
          super + "/insurables"
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
        def create_params
          return({}) if params[:insurable].blank?
          to_return = params.require(:insurable).permit(
            :category, :covered, :enabled, :insurable_id,
            :insurable_type_id, :title, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:insurable].blank?
          params.require(:insurable).permit(
            :category, :covered, :enabled, :insurable_id,
            :insurable_type_id, :title, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
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
