##
# V2 StaffSuperAdmin ApplicationModules Controller
# File: app/controllers/v2/staff_super_admin/application_modules_controller.rb

module V2
  module StaffSuperAdmin
    class ApplicationModulesController < StaffSuperAdminController
      
      before_action :set_application_module,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@application_modules, @substrate)
        else
          super(:@application_modules, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @application_module = @substrate.new(create_params)
          if !@application_module.errors.any? && @application_module.save
            render :show,
              status: :created
          else
            render json: @application_module.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @application_module.update(update_params)
            render :show,
              status: :ok
          else
            render json: @application_module.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/application_modules"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_application_module
          @application_module = access_model(::ApplicationModule, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::ApplicationModule)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.application_modules
          end
        end
        
        def create_params
          return({}) if params[:application_module].blank?
          to_return = {}
          return(to_return)
        end
        
        def update_params
          return({}) if params[:application_module].blank?
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
  end # module StaffSuperAdmin
end
