##
# V2 StaffSuperAdmin Staffs Controller
# File: app/controllers/v2/staff_super_admin/staffs_controller.rb

module V2
  module StaffSuperAdmin
    class StaffsController < StaffSuperAdminController
      include StaffsMethods

      before_action :set_staff, only: %i[show update re_invite toggle_enabled]

      def index
        super(:@staffs, ::Staff, :profile)
        @staffs = filter_by_agency_id if params["agency_id"].present?
      end

      def filter_by_agency_id
        @staffs.joins("left join agencies on agencies.id = staffs.organizable_id and staffs.organizable_type='Agency'").
            where("agencies.id=#{params["agency_id"]}")
      end

      def show; end

      def create
        if create_allowed?
          @staff = ::Staff.new(create_params)
          # remove password issues from errors since this is a Devise model
          @staff.valid? if @staff.errors.blank?
          @staff.errors.messages.except!(:password)
          if @staff.errors.none? && @staff.invite_as(current_staff)
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
        if @staff.update_as(current_staff, update_params)
          render :show, status: :ok
        else
          render json: @staff.errors, status: :unprocessable_entity
        end
      end

      def search
        @staff = ::Staff.search(params[:query]).records
        render json: @staff.to_json, status: 200
      end

      def toggle_enabled
        @staff.toggle!(:enabled)
        render json: { success: true }, status: :ok
      end


      private

      def view_path
        super + '/staffs'
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
          profile_attributes: %i[
            birth_date contact_email contact_phone first_name
            job_title last_name middle_name suffix title
          ]
        )
        to_return
      end

      def update_params
        params.permit(
          :email, notification_options: {}, settings: {},
                  profile_attributes: %i[
                    id birth_date contact_email contact_phone first_name
                    job_title last_name middle_name suffix title
                  ]
        )
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          email: %i[scalar array like],
          permissions: %i[scalar array],
          organizable_id: %i[scalar array],
          organizable_type: %i[scalar array],
          profile: {
            first_name: %i[scalar like],
            last_name: %i[scalar like],
            full_name: %i[scalar like]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end

    end
  end # module StaffSuperAdmin
end
