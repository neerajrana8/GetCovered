##
# V2 StaffAgency Users Controller
# File: app/controllers/v2/staff_agency/users_controller.rb

module V2
  module StaffAgency
    class UsersController < StaffAgencyController
      before_action :set_user, only: %i[update show]

      check_privileges 'property_management.users'

      def index
        query = @agency.active_users
        if params[:community_like]
          communities = Insurable.where(insurable_type_id: InsurableType::COMMUNITIES_IDS).where("title ILIKE ?", "%#{params[:community_like]}%")
          unit_ids = communities.map{ |c| c.units.pluck(:id) }.flatten
          policy_ids = PolicyInsurable.where(insurable_id: unit_ids).pluck(:policy_id)
          query = query.references(:policy_users).includes(:policy_users).where(policy_users: { policy_id: policy_ids })
        end

        if params[:t_code]
          query = query.joins(:integration_profiles).where(integration_profiles: { external_id: params[:t_code], external_context: "resident" })
        end

        super(:@users, query, :profile, :accounts)
        render template: 'v2/shared/users/index', status: :ok
      end

      def search
        @users = ::User.search(query: { match: { email: { query: params[:query], analyzer: 'standard'} } } ).records
        render json: @users.records.to_json, status: :ok
      end


      def show
        if @user
          render template: 'v2/shared/users/show', status: :ok
        else
          render json: { user: 'not found' }, status: :not_found
        end
      end

      def create
        if create_allowed?
          @user = ::User.new(create_params)
          # remove password issues from errors since this is a Devise model
          @user.valid? if @user.errors.blank?
          #because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
          #@user.errors.messages.except!(:password)
          if (!@user.errors.any?|| only_password_blank_error?(@user.errors) ) && @user.invite_as!(current_staff)
            render template: 'v2/shared/users/show',
              status: :created
          else
            render json: @user.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def update
        if update_allowed?
          if @user.update_as(current_staff, update_params)
            render template: 'v2/shared/users/show',
                   status: :ok
          else
            render json: @user.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      private

      def only_password_blank_error?(user_errors)
        user_errors.messages.keys == [:password]
      end

      def view_path
        super + '/users'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_user
        @user = @agency.active_users.find_by(id: params[:id])
      end

      def create_params
        return({}) if params[:user].blank?

        to_return = params.require(:user).permit(
          :email, :enabled, notification_options: {}, settings: {},
                            profile_attributes: %i[
                              birth_date contact_email contact_phone first_name
                              job_title last_name middle_name suffix title gender salutation
                            ]
        )
        to_return
      end

      def update_params
        return({}) if params[:user].blank?

        params.require(:user).permit(
          :enabled, notification_options: {}, settings: {},
                    profile_attributes: %i[
                      birth_date contact_email contact_phone first_name
                      job_title last_name middle_name suffix title gender salutation
                    ]
        )
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          email: %i[scalar array like],
          profile: {
            full_name: %i[scalar array like]
          },
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
          has_existing_policies: %i[scalar array],
          has_current_leases: %i[scalar array],
          accounts: { agency_id: %i[scalar array], id: %i[scalar array] },
          insurables: { id: %i[scalar array], title: %i[scalar array like] }
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
