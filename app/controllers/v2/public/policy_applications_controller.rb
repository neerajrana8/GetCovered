##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb

module V2
  module Public
    class PolicyApplicationsController < PublicController
      
      before_action :set_policy_application,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create]
      
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
      
      def update
        if update_allowed?
          if @policy_application.update(update_params)
            render :show,
              status: :ok
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
        
        def update_allowed?
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
        
        def update_params
          return({}) if params[:policy_application].blank?
          to_return = {}
        end
        
    end
  end # module Public
end
