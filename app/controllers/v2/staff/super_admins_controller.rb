module V2
  module Staff
    class SuperAdminsController < ApplicationController
      before_action :only_super_admins
      before_action :set_super_admin, only: [:show, :update, :destroy]
      
      def index
        @super_admins = SuperAdmin.all
      end
      
      def show
      end
      
      def create
        @super_admin = SuperAdmin.new(super_admin_params)
        
        if @super_admin.save
          render :show, status: :created, location: @super_admin
        else
          render json: @super_admin.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @super_admin.update(super_admin_params)
          render :show, status: :ok, location: @super_admin
        else
          render json: @super_admin.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @super_admin.destroy
      end
      
      private
      def set_super_admin
        @super_admin = SuperAdmin.find(params[:id])
      end
      
      def super_admin_params
        params.fetch(:super_admin, {})
      end
    end
  end
end
