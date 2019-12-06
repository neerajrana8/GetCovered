##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb

module V2
  module Public
    class PolicyApplicationsController < PublicController
      
      before_action :set_policy_application,
        only: %i[update show]
      
      before_action :set_substrate,
        only: [:create]
      
      def show
        if %w[started in_progress
              abandoned more_required].include?(@policy_application.status)
            
        else

          render json: { error: 'Policy Application is not found or no longer available' }.to_json,
                 status: 404
        end
      end
      
      def new
        selected_policy_type = params[:policy_type].blank? ? 'residential' : params[:policy_type]
        if valid_policy_types.include?(selected_policy_type)
          policy_type = PolicyType.find_by_slug(selected_policy_type)
          carrier = selected_policy_type == 'residential' ? Carrier.find(1) : Carrier.find(3)
          
          @application = PolicyApplication.new(policy_type: policy_type, carrier: carrier)
          @application.build_from_carrier_policy_type
          @primary_user = ::User.new
          @application.users << @primary_user
          
        else
          render json: { error: 'Invalid policy type' },
                 status: :unprocessable_entity
        end
      end
      
      def create
        if create_allowed?
          @policy_application = @substrate.new(create_params)
          if @policy_application.errors.none? && @policy_application.save
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
        super + '/policy_applications'
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
        to_return
      end
        
      def update_params
        return({}) if params[:policy_application].blank?

        to_return = {}
      end
        
      def valid_policy_types
        %w[residential commercial]
      end
        
    end
  end # module Public
end
