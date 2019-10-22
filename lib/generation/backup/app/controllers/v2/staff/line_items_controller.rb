# frozen_string_literal: true

module V2
  module Staff
    class LineItemsController < StaffController
      before_action :only_super_admins
      before_action :set_line_item, only: [:show, :update, :destroy]
      
      def index
        @line_items = LineItem.all
      end
      
      def show
      end
      
      def create
        @line_item = LineItem.new(line_item_params)
        
        if @line_item.save
          render :show, status: :created, location: @line_item
        else
          render json: @line_item.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @line_item.update(line_item_params)
          render :show, status: :ok, location: @line_item
        else
          render json: @line_item.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @line_item.destroy
      end
      
      private
      def set_line_item
        @line_item = LineItem.find(params[:id])
      end
      
      def line_item_params
        params.require(:line_item).permit(:title, :price, :invoice_id)
      end
    end
  end
end
