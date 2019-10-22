##
# V2 StaffAgency Notes Controller
# File: app/controllers/v2/staff_agency/notes_controller.rb

module V2
  module StaffAgency
    class NotesController < StaffAgencyController
      
      before_action :set_note,
        only: [:update, :destroy, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@notes)
        else
          super(:@notes)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @note = @substrate.new(create_params)
          if !@note.errors.any? && @note.save
            render :show,
              status: :created
          else
            render json: @note.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @note.update(update_params)
            render :show,
              status: :ok
          else
            render json: @note.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @note.destroy
            render json: { success: true },
              status: :ok
          else
            render json: { success: false },
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/notes"
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
        
        def set_note
          @note = access_model(::Note, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Note)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.notes
          end
        end
        def create_params
          return({}) if params[:note].blank?
          to_return = {}
          return(to_return)
        end
        
        def update_params
          return({}) if params[:note].blank?
          to_return = {}
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffAgency
end
