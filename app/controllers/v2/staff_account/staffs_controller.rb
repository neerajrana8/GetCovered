##
# V2 StaffAccount Staffs Controller
# File: app/controllers/v2/staff_account/staffs_controller.rb

module V2
  module StaffAccount
    class StaffsController < StaffAccountController
      include StaffsMethods

      before_action :set_staff, only: %i[update show toggle_enabled re_invite]
      before_action :validate_password_changing, only: %i[update]

      def index
        super(:@staffs, current_staff.organizable.staff, :profile)
      end

      def show; end

      def create
        if create_allowed?
          if create_params[:id].present?
            @staff = ::Staff.find create_params[:id]
            check_roles(@staff, create_params[:staff_roles_attributes])

            if @staff.errors.none?
              add_roles(@staff, create_params[:staff_roles_attributes])
            else
              render json: @staff.errors,
                     status: :unprocessable_entity
            end
          else
            @staff = current_staff.organizable.staff.new(create_params)
            # remove password issues from errors since this is a Devise model
            @staff.valid? if @staff.errors.blank?
          end

          #because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
          #@staff.errors.messages.except!(:password)
          if (@staff.errors.none? || only_password_blank_error?(@staff.errors) ) && @staff.invite_as(current_staff)
            if @staff.staff_roles.count === 0
              build_first_role(@staff)
            end
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

      def search
        @staff = ::Staff.search(params[:query]).records.where(organizable_id: current_staff.organizable_id)
        render json: @staff.to_json, status: 200
      end

      def toggle_enabled
        if current_staff.owner && current_staff.organizable == @staff.organizable
          @staff.toggle!(:enabled)
          render json: { success: true }, status: :ok
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end

      private

      def only_password_blank_error?(staff_errors)
        staff_errors.messages.keys == [:password]
      end

      def view_path
        super + '/staffs'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_staff
        @staff = current_staff.organizable.staff.find_by(id: params[:id])
      end

      def create_params
        return({}) if params[:staff].blank?

        to_return = params.require(:staff).permit(
          :id, :email, notification_options: {}, settings: {},
                  profile_attributes: %i[
                    birth_date contact_email contact_phone first_name
                    job_title last_name middle_name suffix title
                  ], staff_roles_attributes: [
                    :organizable_id, :organizable_type, :role,
                    global_permission_attributes: {permissions: {}}
                  ]
        )
        to_return
      end

      def update_params
        return({}) if params[:staff].blank?

        params.require(:staff).permit(
          :email, :password, :password_confirmation,
          notification_options: {},
          settings: {},
          staff_permission_attributes: [permissions: {}],
          profile_attributes: %i[
            id birth_date contact_email contact_phone first_name
            job_title last_name middle_name suffix title
          ], staff_roles_attributes: [
            :id, global_permission_attributes: {permissions: {}}
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
          created_at: %i[scalar array],
          updated_at: %i[scalar array],
          enabled: %i[scalar array],
          owner: %i[scalar array],
          current_sign_in_at: %i[scalar array],
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

      def validate_password_changing
        if update_params[:password].present? && !@staff.valid_password?(params[:staff][:current_password])
          error_object =
            if @staff.invitation_accepted?
              standard_error(:wrong_current_password, I18n.t('devise_token_auth.passwords.missing_current_password'))
            else
              standard_error(:invitation_was_not_accepted, 'Invitation was not accepted')
            end
          render json: error_object, status: :unprocessable_entity
        end
      end
    end
  end # module StaffAccount
end
