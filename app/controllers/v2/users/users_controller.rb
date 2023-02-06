module V2
  module Users
    class UsersController < ApiController
      include ActionController::Caching

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

            buildings_ids = []
            units_ids = []
            insurables = Insurable.where(insurable_id: community_ids)
            insurables.each do |i|
              if ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(i.insurable_type_id)
                buildings_ids << i.id
              end

              if ::InsurableType::RESIDENTIAL_IDS.include?(i.insurable_type_id)
                units_ids << i.id
              end
            end

            if buildings_ids.count.positive?
              units_from_buildings = Insurable.where(insurable_id: buildings_ids)
              units_ids += units_from_buildings.pluck(:id)
            end

            leases = Lease.where(insurable_id: units_ids)
            lease_ids = leases.pluck(:id)
            users = users.references(:lease_users).includes(:lease_users).where(lease_users: { lease_id: lease_ids })
            users = ::User.where(id: users.pluck(:id))
          end

          if params[:filter][:account_id].present?
            account_ids = params[:filter][:account_id]
            users = users.includes(:account_users).where(account_users: { account_id: account_ids })
          end

          if params[:filter][:has_existing_policies].present?
            users = users.where(has_existing_policies: params[:filter][:has_existing_policies])
          end

          if params[:filter][:has_leases].present?
            users = users.where(has_leases: params[:filter][:has_leases])
          end

          if params[:filter][:has_current_leases].present?
            users = users.where(has_current_leases:  params[:filter][:has_current_leases])
          end

          if params[:filter][:full_name].present?
            users = users.joins(:profile).where("profiles.full_name ILIKE '%#{params[:filter][:full_name]}%'")
          end

          if params[:filter][:email].present?
            users = users.where("email ILIKE '%#{params[:filter][:email]}%'")
          end

          # Filtering by tcode
          if params[:filter][:tcode].present?
            matched_integrations =
              IntegrationProfile.where('profileable_type = ? AND external_id LIKE ?', 'User', "%#{params[:filter][:tcode]}%")
            matched_integrations_user_ids = matched_integrations.pluck(:profileable_id)
            users = users.where(id: matched_integrations_user_ids)
          end
        end

        # Sorting
        if params[:sort].present?
          users = users.order(email: params[:sort][:email]) if params[:sort][:email].present?
          users = users.order(created_at: params[:sort][:created_at]) if params[:sort][:created_at].present?
        end

        # Pagination
        if params[:pagination].present?
          page = params[:pagination][:page] if params[:pagination][:page]
          per = params[:pagination][:per] if params[:pagination][:per]
        end

        @meta = { total: users.count, page: page, per: per }
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
