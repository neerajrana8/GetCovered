module V2
  module Public
    class UnitsController < PublicController
      def communities
        community = Insurable.find(params[:id])
        @account_units = community.insurables.units
        render '/v2/staff_super_admin/accounts/account_units', status: :ok
      end
    end
  end
end