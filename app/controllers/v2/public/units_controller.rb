module V2
  module Public
    class UnitsController < PublicController
      def communities
        # Fetch Community or Building
        community = Insurable.where(id: params[:id], insurable_type_id: InsurableType::COMMUNITIES_IDS + InsurableType::BUILDINGS_IDS).take
        @account_units = community.units
        render '/v2/staff_super_admin/accounts/account_units', status: :ok
      end
    end
  end
end