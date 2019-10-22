##
# V2 User PolicyApplications Controller
# File: app/controllers/v2/user/policy_applications_controller.rb

module V2
  module User
    class PolicyApplicationsController < UserController
      
      before_action :set_policy_application,
        only: [:show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@policy_applications)
        else
          super(:@policy_applications)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @policy_application = @substrate.new(create_params)
          if !@policy_application.errors.any? && @policy_application.save
            render :show,
              status: :created
          else
            render json: @policy_application.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/policy_applications"
        end
        
        def create_allowed?
          true
        end
        
        def set_policy_application
          @policy_application = access_model(::PolicyApplication, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::PolicyApplication)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policy_applications
          end
        end
        def create_params
          return({}) if params[:policy_application].blank?
          to_return = {}
          return(to_return)
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
  end # module User
end
