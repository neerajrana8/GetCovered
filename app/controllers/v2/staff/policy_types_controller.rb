module V1
  module Staff
    
    class PolicyTypesController < StaffController
      before_action :set_policy_type, only: [:show, :update, :destroy]
      
      def index
        @policy_types = PolicyType.all
      end
      
      def show
      end
      
      def create
        @policy_type = PolicyType.new(policy_type_params)
        
        if @policy_type.save
          render :show, status: :created, location: @policy_type
        else
          render json: @policy_type.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @policy_type.update(policy_type_params)
          render :show, status: :ok, location: @policy_type
        else
          render json: @policy_type.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @policy_type.destroy
      end
      
      private
      def set_policy_type
        @policy_type = PolicyType.find(params[:id])
      end
      
      def policy_type_params
        params.require(:policy_type).permit(:title, :slug, :enabled)
      end
    end
  end
end