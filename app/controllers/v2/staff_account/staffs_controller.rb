##
# V2 StaffAccount Staffs Controller
# File: app/controllers/v2/staff_account/staffs_controller.rb

module V2
  module StaffAccount
    class StaffsController < StaffAccountController
      
      before_action :set_staff,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@staffs, :profile)
        else
          super(:@staffs, :profile)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @staff = @substrate.new(create_params)
          # remove password issues from errors since this is a Devise model
          @staff.valid? if @staff.errors.blank?
          @staff.errors.messages.except!(:password)
          if !@staff.errors.any? && @staff.invite_as!(current_staff)
            render :show,
              status: :created
          else
            render json: @staff.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @staff.update_as(current_staff, update_params)
            render :show,
              status: :ok
          else
            render json: @staff.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/staffs"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_staff
          @staff = access_model(::Staff, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Staff)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.staffs
          end
        end
        def create_params
          return({}) if params[:staff].blank?
          to_return = params.require(:staff).permit(
            :email, :enabled, notification_options: {}, settings: {},
            profile_attributes: [
              :birth_date, :contact_email, :contact_phone, :first_name,
              :job_title, :last_name, :middle_name, :suffix, :title
            ]
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:staff].blank?
          params.require(:staff).permit(
            :enabled, notification_options: {}, settings: {},
            profile_attributes: [
              :birth_date, :contact_email, :contact_phone, :first_name,
              :job_title, :last_name, :middle_name, :suffix, :title
            ]
          )
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
  end # module StaffAccount
end
