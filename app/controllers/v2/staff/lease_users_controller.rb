# frozen_string_literal: true

module V1
  module Staff
    class LeaseUsersController < StaffController
      before_action :only_super_admins
      before_action :set_lease_user, only: [:show, :update, :destroy]
      
      def index
        @lease_users = LeaseUser.all
      end
      
      def show
      end
      
      def create
        @lease_user = LeaseUser.new(lease_user_params)
        
        if @lease_user.save
          render :show, status: :created, location: @lease_user
        else
          render json: @lease_user.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @lease_user.update(lease_user_params)
          render :show, status: :ok, location: @lease_user
        else
          render json: @lease_user.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @lease_user.destroy
      end
      
      private
      def set_lease_user
        @lease_user = LeaseUser.find(params[:id])
      end
      
      def lease_user_params
        params.require(:lease_user).permit(:lease_id, :user_id)
      end
    end
  end
end