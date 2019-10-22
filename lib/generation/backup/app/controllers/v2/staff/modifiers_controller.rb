# frozen_string_literal: true

module V2
  module Staff
    class ModifiersController < StaffController
      before_action :only_super_admins
      before_action :set_modifier, only: [:show, :update, :destroy]
      
      def index
        @modifiers = Modifier.all
      end
      
      def show
      end
      
      def create
        @modifier = Modifier.new(modifier_params)
        
        if @modifier.save
          render :show, status: :created, location: @modifier
        else
          render json: @modifier.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @modifier.update(modifier_params)
          render :show, status: :ok, location: @modifier
        else
          render json: @modifier.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @modifier.destroy
      end
      
      private
      def set_modifier
        @modifier = Modifier.find(params[:id])
      end
      
      def modifier_params
        params.require(:modifier)
              .permit(:strategy, :amount, :tier, :condition, :invoice_id)
      end
    end
  end
end
