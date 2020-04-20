##
# V2 StaffSuperAdmin Staffs Controller
# File: app/controllers/v2/staff_super_admin/staffs_controller.rb

module V2
  module StaffSuperAdmin
    class StaffsController < StaffSuperAdminController
      
      before_action :set_staff, only: [:show, :re_invite, :toggle_enabled]
            
      def index
        super(:@staffs, Staff, :profile)
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @staff = Staff.new(create_params)
          # remove password issues from errors since this is a Devise model
          @staff.valid? if @staff.errors.blank?
          @staff.errors.messages.except!(:password)
          if !@staff.errors.any? && @staff.invite_as(current_staff)
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

      def search
        @staff = Staff.search(params[:query]).records
        render json: @staff.to_json, status: 200
      end

      def re_invite
        if @staff.invite_as(current_staff)
          render json: { success: true }, status: :ok
        else
          render json: { success: false,
                         errors: { staff: 'Unable to re-invite Staff', rails_errors: @staff.errors.to_h } },
                 status: :unprocessable_entity
        end
      end

      def toggle_enabled
        @staff.toggle!(:enabled)
        render json: { success: true }, status: :ok
      end

      
      private
      
        def view_path
          super + "/staffs"
        end
        
        def create_allowed?
          true
        end
        
        def set_staff
          @staff = access_model(::Staff, params[:id])
        end
                
        def create_params
          return({}) if params[:staff].blank?
          to_return = params.require(:staff).permit(
            :email, :enabled, :organizable_id, :organizable_type, :role,
            notification_options: {}, settings: {},
            profile_attributes: [
              :birth_date, :contact_email, :contact_phone, :first_name,
              :job_title, :last_name, :middle_name, :suffix, :title
            ]
          )
          return(to_return)
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
            id: [ :scalar, :array ],
            email: [ :scalar, :array, :like ],
            permissions: [ :scalar, :array ],
            organizable_id: [ :scalar, :array ],
            organizable_type: [ :scalar, :array ],
            profile: {
              first_name: [ :scalar, :like ],
              last_name: [ :scalar, :like ],
              full_name: [ :scalar, :like ]
            }
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffSuperAdmin
end
