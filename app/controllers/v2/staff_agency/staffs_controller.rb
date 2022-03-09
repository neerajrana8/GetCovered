##
# V2 StaffAgency Staffs Controller
# File: app/controllers/v2/staff_agency/staffs_controller.rb

module V2
  module StaffAgency
    class StaffsController < StaffAgencyController
      include StaffsMethods

      before_action :set_staff, only: %i[update update_self show re_invite toggle_enabled]
      before_action :validate_password_changing, only: %i[update_self]

      check_privileges 'agencies.agents' => %i[index create update show re_invite toggle_enabled]
      check_privileges 'agencies.manage_agents' => %i[create update]

      def index
        if (params[:filter] && params[:filter][:organizable_type] == 'Account')
          super(:@staffs, @agency.account_staff, :profile)
        else
          super(:@staffs, @agency.staff, :profile)
        end
      end

      def show
        if show_allowed?
          render :show, status: :ok
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end

      end

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
            @staff = ::Staff.new(create_params)
            # remove password issues from errors since this is a Devise model
            @staff.valid? if @staff.errors.blank?
          end

          # because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
          # @staff.errors.messages.except!(:password)
          if (@staff.errors.none? || only_password_blank_error?(@staff.errors) ) && @staff.invite_as!(current_staff)
            if @staff.staff_roles.count === 0
              build_first_role(@staff)
            end
            render :show, status: :created
          else
            render json: @staff.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end

      def update
        if @staff.update_as(current_staff, update_params)
          render :show, status: :ok
        else
          render json: standard_error(:staff_update_error, nil, @staff.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def update_self
        if @staff.update_as(current_staff, update_params) && @staff == current_staff
          render :show, status: :ok
        else
          render json: standard_error(:staff_update_error, nil, @staff.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def search
        @staff = ::Staff.search(params[:query]).records.where(organizable_id: @agency.id)
        render json: @staff.to_json, status: 200
      end

      def toggle_enabled
        if show_allowed? && current_staff.owner
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

      def show_allowed?
        return true if @agency == @staff.organizable

        return true if current_staff.getcovered_agent?

        return true if @agency.agencies.include?(@staff.organizable)

        return true if @agency.accounts.include?(@staff.organizable)

        false
      end

      def create_allowed?
        return false if create_params[:role] == 'super_admin'

        return true if current_staff.getcovered_agent?

        return true if create_params[:organizable_type] == 'Agency' && (@agency.id == create_params[:organizable_id]&.to_i || @agency.agencies.ids.include?(create_params[:organizable_id]&.to_i))

        return false if create_params[:organizable_type] == 'Account' && !@agency&.accounts&.ids&.include?(create_params[:organizable_id])

        true
      end

      def set_staff
        @staff = ::Staff.find(params[:id])
      end

      def create_params
        return({}) if params[:staff].blank?

        to_return = params.require(:staff).permit(
          :id, :email, :organizable_id, :organizable_type, :role,
          notification_options: {}, settings: {},
          profile_attributes: %i[ id
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
  end
end
