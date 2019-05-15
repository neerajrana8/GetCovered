# frozen_string_literal: true

module V2
  module Staff
    class InsurablesController < StaffController
      before_action :only_super_admins, only: [:destroy]
      before_action :set_insurable, only: [:show, :update, :destroy]
      
      def index
        @insurables = Insurable.all
      end
      
      def show
      end
      
      def create
        @insurable = Insurable.new(insurable_params)
        
        if @insurable.save
          render :show, status: :created, location: @insurable
        else
          render json: @insurable.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @insurable.update(insurable_params)
          render :show, status: :ok, location: @insurable
        else
          render json: @insurable.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @insurable.destroy
      end
      
      private
      def set_insurable
        @insurable = Insurable.find(params[:id])
      end
      
      def insurable_params
        params.fetch(:insurable, {})
      end
    end
  end
end