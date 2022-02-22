module V2
  module Public
    class BuildingsController < PublicController
      def community
        community = Insurable.where(id: params[:id], insurable_type_id: InsurableType::COMMUNITIES_IDS).first
        @account_communities = []
        @account_communities = community.buildings if community
        render '/v2/public/communities/accounts', status: :ok
      end
    end
  end
end