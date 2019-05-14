# frozen_string_literal: true

module V1
  module Staff
    class InsurableTypesController < StaffController
      before_action :only_super_admins, only: [:create, :update, :destroy]
      before_action :set_insurable_type, only: [:show, :update, :destroy]
      
      def index
        @insurable_types = InsurableType.all
      end
      
      def show
      end
      
      def create
        @insurable_type = InsurableType.new(insurable_type_params)
        
        if @insurable_type.save
          render :show, status: :created, location: @insurable_type
        else
          render json: @insurable_type.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @insurable_type.update(insurable_type_params)
          render :show, status: :ok, location: @insurable_type
        else
          render json: @insurable_type.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @insurable_type.destroy
      end
      
      private

      def set_insurable_type
        @insurable_type = InsurableType.find(params[:id])
      end
      
      def insurable_type_params
        params.fetch(:insurable_type).permit(:title, :slug, :category, :enabled)
      end
    end
  end
end
