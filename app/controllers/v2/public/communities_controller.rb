module V2
  module Public
    class CommunitiesController < PublicController
      def accounts
        account = Account.includes(:insurables).find(params[:id])
        @account_communities = Insurable.where(account_id: account.id).communities
        render '/v2/staff_agency/accounts/account_communities', status: :ok
      end
    end
  end
end