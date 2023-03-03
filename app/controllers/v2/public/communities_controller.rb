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
          if params[:branding_id].blank?
            render json: standard_error(:branding_profile_id_param_blank,'branding_profile_id parameter can\'t be blank'),
                   status: :unprocessable_entity
          else
            branding_profile = BrandingProfile.find_by_id(params[:branding_profile_id])
            profileable = branding_profile&.profileable_type.eql?("Account") ? Account.find_by_id(branding_profile&.profileable_id) : Agency.find_by_id(branding_profile&.profileable_id)

            if profileable.blank?
              render json: standard_error(:account_not_found,'Account or Agency for this branding_id not found'),
                     status: :unprocessable_entity
            else
              begin
                if branding_profile&.profileable_type.eql?("Account")
                  @communities = Insurable.communities.where(account_id: profileable.id, preferred_ho4: true)
                                   .joins(:addresses).where(addresses: { state: params[:state] } )
                else
                  @communities = Insurable.communities.where(agency_id: profileable.id, preferred_ho4: true)
                                          .joins(:addresses).where(addresses: { state: params[:state] } )
                end
              rescue StandardError => e
                render json: standard_error(:query_failed,"#{e.message}"),
                       status: :unprocessable_entity
              end
            end

          end
        end
      end

      #TODO: think about validations with dry components
      def account_states
        if params[:branding_profile_id].blank?
          render json: standard_error(:branding_profile_id_param_blank,'branding_profile_id parameter can\'t be blank'),
                 status: :unprocessable_entity
        else
          branding_profile = BrandingProfile.find_by_id(params[:branding_profile_id])

          profileable = branding_profile&.profileable_type.eql?("Account") ? Account.find_by_id(branding_profile&.profileable_id) : Agency.find_by_id(branding_profile&.profileable_id)

          if profileable.blank?
            render json: standard_error(:account_not_found,'Account or Agency for this branding_id not found'),
                   status: :unprocessable_entity
          else
            begin
              if branding_profile&.profileable_type.eql?("Account")
                @states = Insurable.communities.includes(:addresses).where(account_id: profileable.id)
                            .where.not(addresses: { state: nil})
                            .extract_associated(:addresses)&.flatten.map(&:state).uniq
              else
                @states = Insurable.communities.includes(:addresses).where(agency_id: profileable.id)
                                   .where.not(addresses: { state: nil})
                                   .extract_associated(:addresses)&.flatten.map(&:state).uniq
              end

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

