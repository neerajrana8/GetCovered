# frozen_string_literal: true

module V1
  module Staff
    class LeaseTypesController < StaffController
      before_action :only_super_admins
      before_action :set_lease_type, only: [:show, :update, :destroy]
      
      def index
        @lease_types = LeaseType.all
      end
      
      def show
      end
      
      def create
        @lease_type = LeaseType.new(lease_type_params)
        
        if @lease_type.save
          render :show, status: :created, location: @lease_type
        else
          render json: @lease_type.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @lease_type.update(lease_type_params)
          render :show, status: :ok, location: @lease_type
        else
          render json: @lease_type.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @lease_type.destroy
      end
      
      private
      def set_lease_type
        @lease_type = LeaseType.find(params[:id])
      end
      
      def lease_type_params
        params.require(:lease_type).permit(:title, :enabled)
      end
    end
  end
end