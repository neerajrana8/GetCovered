# V2 StaffAgency Pages Controller
# File: app/controllers/v2/staff_agency/pages_controller.rb

module V2
  module StaffAgency
    class PagesController < StaffAgencyController
      before_action :set_page, only: [:update, :destroy, :show]
      
      before_action :set_substrate, only: [:create, :index]
      
      def index
        super(:@pages, @substrate)
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @page = @substrate.new(page_params)
          if !@page.errors.any? && @page.save
            render :show, status: :created
          else
            render json: @page.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
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
          @page = access_model(::Page, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Page)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.pages
          end
        end
        
        def page_params
          params.require(:page).permit(:content, :title, :agency_id, :branding_profile_id, styles: {})
        end
        
    end
  end
end
