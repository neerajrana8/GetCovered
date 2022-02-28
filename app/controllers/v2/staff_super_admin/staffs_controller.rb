##
# V2 StaffSuperAdmin Staffs Controller
# File: app/controllers/v2/staff_super_admin/staffs_controller.rb

module V2
  module StaffSuperAdmin
    class StaffsController < StaffSuperAdminController
      include StaffsMethods

      before_action :set_staff, only: %i[show update re_invite toggle_enabled]
      before_action :validate_password_changing, only: %i[update]

      def index
        super(:@staffs, ::Staff, :profile)
        @staffs = filter_by_agency_id if params['agency_id'].present?
      end

      def filter_by_agency_id
        @staffs.joins("left join agencies on agencies.id = staffs.organizable_id and staffs.organizable_type='Agency'").
          where("agencies.id=#{params['agency_id']}")
      end

      def show; end

      def create
        if create_allowed?
          if is_bulk_creation?
            created_staffs = [], errors_staffs = []
            bulk_create_params["property_managers_attributes"].each do |pm_create_params|
              if pm_create_params[:id].present?
                @staff = ::Staff.find pm_create_params[:id]
                check_roles(@staff, pm_create_params[:staff_roles_attributes])

                if @staff.errors.none?
                  add_roles(@staff, pm_create_params[:staff_roles_attributes])
                  if @staff.errors.none?
                    created_staffs << @staff
                  else
                    errors_staffs << {"staff": @staff, "errors": @staff.errors.full_messages}
                  end
                end
              end
              @staff = ::Staff.new(pm_create_params)
              # remove password issues from errors since this is a Devise model
              @staff.valid? if @staff.errors.blank?
              #because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
              #@staff.errors.messages.except!(:password)
              if (@staff.errors.none? || only_password_blank_error?(@staff.errors) ) && @staff.invite_as(current_staff)
                created_staffs << @staff
                #render :show,
                #       status: :created
              else
                errors_staffs << {"staff": @staff, "errors": @staff.errors.full_messages}
                #render json: @staff.errors,
                #      status: :unprocessable_entity
              end
            end

            render json: {
                created: created_staffs,
                #already_created: already_created_insurables,
                errors: errors_staffs
            }
          else
            if create_params[:id].present?
              @staff = ::Staff.find create_params[:id]
              check_roles(@staff, create_params[:staff_roles_attributes])

              if @staff.errors.none?
                add_roles(@staff, create_params[:staff_roles_attributes])
                if @staff.errors.none?
                  render :show,
                         status: :created
                else
                  render json: @staff.errors,
                         status: :unprocessable_entity
                end
              end
            else
              @staff = ::Staff.new(create_params)
              # remove password issues from errors since this is a Devise model
              @staff.valid? if @staff.errors.blank?
              #because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
              #@staff.errors.messages.except!(:password)
              if (@staff.errors.none? || only_password_blank_error?(@staff.errors) ) && @staff.invite_as!(current_staff)
                render :show,
                       status: :created
              else
                render json: @staff.errors,
                       status: :unprocessable_entity
              end
            end
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

      def is_bulk_creation?
        params&.keys&.include?("property_managers_attributes")
      end
        
      def only_password_blank_error?(staff_errors)
        staff_errors.messages.keys == [:password]
      end

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
          :id, :email, :enabled, :organizable_id, :organizable_type, :role,
          notification_options: {}, settings: {},
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

      def bulk_create_params
        return({}) if params[:staff].blank?
        to_return = params.require(:staff).permit(
            property_managers_attributes: [:id, :email, :enabled, :organizable_id, :organizable_type, :role,
                                           notification_options: {}, settings: {},
                                           profile_attributes: %i[
                                              birth_date contact_email contact_phone first_name
                                              job_title last_name middle_name suffix title ]
                                           ], staff_roles_attributes: [
                                            :organizable_id, :organizable_type, :role,
                                            global_permission_attributes: {permissions: {}}
                                           ]
        )
        to_return
      end

      def bulk_create_params_example
        params.require(:insurables).permit(
            common_attributes: [
                :category, :covered, :enabled, :insurable_id, :occupied,
                :insurable_type_id, :account_id, addresses_attributes: %i[
              city country county id latitude longitude
              plus_four state street_name street_number
              street_two timezone zip_code
            ]
            ],
            ranges: []
        )
      end

      def update_params
        params.permit(
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
        if params[:password].present? && !@staff.valid_password?(params[:current_password])
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
  end # module StaffSuperAdmin
end
