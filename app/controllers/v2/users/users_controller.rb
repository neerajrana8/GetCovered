module V2
  module Users
    class UsersController < ApiController
      before_action :authenticate_staff!
      before_action :check_permissions

      def list
        page = 1
        per = 10

        users = if current_staff.role.to_sym == :super_admin
          ::User.all
        else
          current_staff.organizable.active_users
        end

        # Filtering
        if params[:filter].present?
          if params[:filter][:community_id].present?
            community_ids = params[:filter][:community_id]
            policies = PolicyInsurable.where(insurable_id: community_ids)
            policy_ids = policies.pluck(:policy_id)
            users = users.references(:policy_users).includes(:policy_users).where(policy_users: { policy_ids: policy_ids })
          end

          if params[:filter][:account_id].present?
            account_ids = params[:filter][:account_id]
            users = users.includes(:account_users).where(account_users: { account_id: account_ids })
          end

          if params[:filter][:has_policies].present?
            policy_users_ids = PolicyUser.all.pluck(:user_id)
            users = users.where(id: policy_users_ids)
          end

          if params[:filter][:has_leases].present?
            lease_users_ids = LeaseUser.all.pluck(:user_id)
            users = users.where(id: lease_users_ids)
          end
        end

        # Pagination
        if params[:pagination].present?
          page = params[:pagination][:page] if params[:pagination][:page]
          per = params[:pagination][:per] if params[:pagination][:per]
        end
        @users = users.page(page).per(per)
        render template: 'v2/users/list', status: :ok
      end

      def show
        if params[:id].present?
          @user = ::User.includes(:policy_users, :account_users).find(params[:id])
        end
        if @user
          render template: 'v2/users/show', status: :ok
        else
          render json: { errors: [:not_found] }, status: 404
        end
      end


      private

      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end

    end
  end
end
