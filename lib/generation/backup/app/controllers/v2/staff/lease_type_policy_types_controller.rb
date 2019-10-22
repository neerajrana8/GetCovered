# frozen_string_literal: true

module V2
  module Staff
    class LeaseTypePolicyTypesController < StaffController
      before_action :only_super_admins
      before_action :set_lease_type_policy_type, only: [:show, :update, :destroy]
      
      def index
        @lease_type_policy_types = LeaseTypePolicyType.all
      end
      
      def show
      end
      
      def create
        @lease_type_policy_type = LeaseTypePolicyType.new(lease_type_policy_type_params)
        
        if @lease_type_policy_type.save
          render :show, status: :created, location: @lease_type_policy_type
        else
          render json: @lease_type_policy_type.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @lease_type_policy_type.update(lease_type_policy_type_params)
          render :show, status: :ok, location: @lease_type_policy_type
        else
          render json: @lease_type_policy_type.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @lease_type_policy_type.destroy
      end
      
      private
      def set_lease_type_policy_type
        @lease_type_policy_type = LeaseTypePolicyType.find(params[:id])
      end
      
      def lease_type_policy_type_params
        params.require(:lease_type_policy_type)
              .permit(:enabled, :lease_type_id, :policy_type_id)
      end
    end
  end
end
