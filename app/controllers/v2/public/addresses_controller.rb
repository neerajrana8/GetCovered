##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module Public
    class AddressesController < PublicController

      def index
        if params[:search].presence
          @addresses = Address.search_insurables(params[:search])
          @ids = @addresses.select{|a| a['_source']['addressable_type'] == 'Insurable' && a['_source']['enabled'] }.map{|a| a['_source']['addressable_id'] }

          @insurables = Insurable.where(id: @ids, enabled: true)
                                 .send(*(params[:policy_type_id].blank? ? [:itself] : [:where, "policy_type_ids @> ARRAY[?]::bigint[]", params[:policy_type_id].to_i]))
                                 .send(*(params[:policy_type_id].to_i == PolicyType::RESIDENTIAL_ID ? [:where, { preferred_ho4: true }] : [:itself]))
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
      
      
      def get_units
        # get a valid address model if possible
        address = ::Address.from_string(params[:address])
        unless address.errors.blank?
          render json: standard_error(:invalid_address, 'Invalid address value', address.errors.full_messages),
                 status: 422
          return
        end
        # search for the insurable
        results = ::Insurable.find_from_address(address, { enabled: true, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS }, allow_multiple: false)
        if results.nil? || (::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(results.insurable_type_id) && (!results.parent_community.preferred_ho4 || !results.parent_community.enabled))
          render json: { id: nil, preferred_ho4: false, units: nil },
            status: 200
          return
        end
        i = results
        render json: {
          id: i.id,
          title: i.title,
          enabled: i.enabled,
          preferred_ho4: true,
          account_id: i.account_id,
          agency_id: i.account.agency_id,
          insurable_type_id: i.insurable_type_id,
          category: i.category,
          covered: i.covered,
          created_at: i.created_at,
          updated_at: i.updated_at,
          addresses: i.addresses,
          units: i.units.select{|u| u.enabled }.map{|u| { id: u.id, title: u.title } }
        }, status: 200
      end
      
      
      private
      
        def get_units_params
          params.require(:address)
        end
      
    end
  end
end
