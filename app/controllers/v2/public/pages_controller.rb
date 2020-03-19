##
# V2 Public Pages Controller
# File: app/controllers/v2/public/pages_controller.rb

module V2
  module Public
    class PagesController < PublicController
	  	before_action :set_page, only: [:show]

      def show
        render :show, status: :ok
      end
      
      private
      
      def set_page
        @page = Page.find(params[:id])
      end
	  end
	end
end