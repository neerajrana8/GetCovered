##
# V2 User Policies Controller
# File: app/controllers/v2/user/policies_controller.rb

module V2
  module User
    class PoliciesController < UserController

      skip_before_action :authenticate_user!, only: [:bulk_decline, :render_eoi]

      before_action :user_from_invitation_token, only: [:bulk_decline, :render_eoi]
      
      before_action :set_policy, only: [:show]
      
      before_action :set_substrate, only: [:index]
      
      def index
        if params[:short]
          super(:@policies, @substrate)
        else
          super(:@policies, @substrate)
        end
      end
      
      def show
      end

      def bulk_decline
        @policy = ::Policy.find(params[:id])
        render json: { errors: ['Unauthorized Access'] }, status: :unauthorized and return unless @policy.primary_user == @user

        @policy.bulk_decline
        render json: { message: 'Policy is declined' }
      end

      def render_eoi
        @policy = ::Policy.find(params[:id])
        render json: { errors: ['Unauthorized Access'] }, status: :unauthorized and return unless @policy.primary_user == @user

        render json: {
          evidence_of_insurance: open("#{Rails.root}/app/views/v2/pensio/evidence_of_insurance.html.erb") { |f| f.read }.html_safe,
          summary: open("#{Rails.root}/app/views/v2/pensio/summary.html.erb") { |f| f.read }.html_safe,
        }
      end
      
      
      private
      
        def view_path
          super + "/policies"
        end
        
        def set_policy
          @policy = access_model(::Policy, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Policy)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policies
          end
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
