module V2
  module Public
    class BuildingsController < PublicController
      def community
        community = Insurable.where(id: params[:id], insurable_type_id: InsurableType::BUILDINGS_IDS).first
        @buildings = []
        @buildings = community.buildings if community
      end
    end
  end
end