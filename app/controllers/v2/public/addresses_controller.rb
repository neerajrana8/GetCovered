##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module Public
    class AddressesController < PublicController

      def index
        if params[:search].presence
          @addresses = Address.search_insurables(params[:search])
          @ids = @addresses.map { |a| a['_source']['addressable_id'] }

          @insurables = Insurable.find(@ids)

          @response = []

          @insurables&.each do |i|
            if (InsurableType::COMMUNITIES_IDS | InsurableType::BUILDINGS_IDS).include?(i.insurable_type_id)
              @response.push(
                id: i.id,
                title: i.title,
                enabled: i.enabled,
                account_id: i.account_id,
                agency_id: i.account.agency_id,
                insurable_type_id: i.insurable_type_id,
                category: i.category,
                covered: i.covered,
                created_at: i.created_at,
                updated_at: i.updated_at,
                addresses: i.addresses,
                insurables: i.units
              )
            end
          end

          render json: @response.to_json,
                 status: :ok
        else
          render json: [].to_json,
                 status: :ok
        end
      end
    end
  end
end
