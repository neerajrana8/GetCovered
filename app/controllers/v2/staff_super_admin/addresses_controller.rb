##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module StaffSuperAdmin
    class AddressesController < StaffSuperAdminController
      def index
        if params[:search].presence
          @addresses = Address.search_insurables(params[:search])
          @ids = @addresses.select{|a| a['_source']['addressable_type'] == 'Insurable' }.map{|a| a['_source']['addressable_id'] }

          @insurables = Insurable.where(id: @ids, enabled: true)
                                 .send(*(params[:policy_type_id].blank? ? [:itself] : [:where, "policy_type_ids @> ARRAY[?]::bigint[]", params[:policy_type_id].to_i]))
                                 .send(*(params[:policy_type_id].to_i == PolicyType::RESIDENTIAL_ID ? [:where, { preferred_ho4: true }] : [:itself]))
                                 .send(*(params[:account_id].present? ? [:where, { account_id: params[:account_id] }] : [:itself]))
                                 .send(*(params[:agency_id].present? ?  [:where, { agency_id: params[:agency_id] }] : [:itself]))
          @response = []

          @insurables&.each do |i|
            if (InsurableType::COMMUNITIES_IDS | InsurableType::BUILDINGS_IDS).include?(i.insurable_type_id)
              @response.push(
                id: i.id,
                title: i.title,
                enabled: i.enabled,
                preferred_ho4: i.preferred_ho4,
                account_id: i.account_id,
                agency_id: i.account.agency_id,
                insurable_type_id: i.insurable_type_id,
                category: i.category,
                covered: i.covered,
                created_at: i.created_at,
                updated_at: i.updated_at,
                addresses: i.addresses,
                insurables: i.units.select{|u| u.enabled }
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
