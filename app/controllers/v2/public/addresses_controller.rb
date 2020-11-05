##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module Public
    class AddressesController < PublicController

      def index
        if params[:search].presence
          @addresses = Address.search_insurables(params[:search])
          @ids = @addresses.select{|a| a['_source']['addressable_type'] == 'Insurable' }.map{|a| a['_source']['addressable_id'] }

          @insurables = Insurable.where(id: @ids, enabled: true)
                                 .send(*(params[:policy_type_id].blank? ? [:itself] : [:where, [ "policy_type_ids @> ARRAY[?]::bigint[]" ], [params[:policy_type_id].to_i]]))
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
        parsed_address = StreetAddress::US.parse(params[:address])
        if parsed_address.nil?
          render json: standard_error(:invalid_address, 'The submitted address is invalid'),
                 status: 404
          return
        end
        ['street_number', 'street_name', 'city', 'state', 'zip_code'].each do |prop|
          if parsed_address[prop].blank?
            render json: standard_error(:invalid_address, "The submitted address is invalid: #{prop.gsub('_',' ')} required"),
                   status: 404
            return
          end
        end
        address = Address.new(full: params[:address])
        address.from_full
        unless address.valid?
          render json: standard_error(:user_creation_error, "Invalid address", address.errors.full_messages),
                status: 422
          return
        end
        # search for the insurable
        results = ::Insurable.find_from_address(addr, { enabled: true, preferred_h04: true, insurable_type_ids: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS })
        if results.nil?
          render json: { preferred_ho4: false, units: nil },
            status: 200
          return
        else
          render json: { preferred_ho4: true, units: ::Insurable.where(insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS, insurable_id: results.id, enabled: true).map{|u| { id: u.id, title: u.title } } }
        end
      end
      
      
      private
      
        def get_units_params
          params.require(:address)
        end
      
    end
  end
end
