module V2
  module Public
    class CommunitiesController < PublicController
      def accounts
        account = Account.includes(:insurables).find(params[:id])
        @account_communities = Insurable.where(account_id: account.id).communities
      end

      def communities
        if params[:state].blank?
          render json: standard_error(:state_param_blank,'State parameter can\'t be blank'),
                 status: :unprocessable_entity
        else
          @communities = Insurable.communities.joins(:addresses).where(addresses: { state: params[:state] } )
        end
      end

      def account_states
        if params[:branding_profile_id].blank?
          render json: standard_error(:branding_profile_id_param_blank,'branding_profile_id parameter can\'t be blank'),
                 status: :unprocessable_entity
        else
          account_id = BrandingProfile.find_by_id(params[:branding_profile_id])&.profileable_id
          account = Account.find_by_id(account_id)

          if account.blank?
            render json: standard_error(:account_not_found,'Account for this branding_id not found'),
                   status: :unprocessable_entity
          else
            begin
              @states = Insurable.communities.includes(:addresses).where(account_id: account.id)
                            .where.not(addresses: { state: nil})
                            .extract_associated(:addresses)&.flatten.map(&:state).uniq
              render json: @states.to_json,
                     status: :ok
            rescue StandardError => e
              render json: standard_error(:query_failed,"#{e.message}"),
                     status: :unprocessable_entity
            end
          end
        end
      end

    end
  end
end

