# V2 StaffSuperAdmin Pages Controller
# File: app/controllers/v2/staff_super_admin/pages_controller.rb

module V2
  module StaffSuperAdmin
    class PagesController < StaffSuperAdminController
      before_action :set_page, only: [:update, :destroy, :show]
            
      def index
        super(:@pages, Page)
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @page = Page.new(page_params)
          if !@page.errors.any? && @page.save
            render :show, status: :created
          else
            render json: @page.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @page.update(page_params)
            render :show, status: :ok
          else
            render json: @page.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @page.destroy
            render json: { success: true }, status: :ok
          else
            render json: { success: false }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/pages"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def destroy_allowed?
          true
        end
        
        def set_page
          @page = Page.find(params[:id])
        end
                
        def page_params
          params.require(:page).permit(:content, :title, :agency_id, :branding_profile_id, styles: {})
        end
        
    end
  end
end
