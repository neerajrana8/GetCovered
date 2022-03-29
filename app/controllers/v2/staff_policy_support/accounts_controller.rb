module V2
  module StaffPolicySupport
    class AccountsController < StaffPolicySupportController
      before_action :set_substrate, only: [:index]

      def index
        if params[:short]
          super(:@accounts, Account)
        else
          super(:@accounts, Account, :agency)
        end
      end

      def account_communities
        account = Account.includes(:insurables).find(params[:id])
        @account_communities = paginator(Insurable.where(account_id: account.id).communities)
        render '/v2/staff_super_admin/accounts/account_communities', status: :ok
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Account)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.accounts
        end
      end

      def view_path
        super + "/accounts"
      end

    end
  end
end
