##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurablesController < PublicController
      
      before_action :set_insurable,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@insurables, @substrate)
        else
          super(:@insurables, @substrate)
        end
      end
      
      def show
      end
      
      def msi_unit_list
        # expected input:
        # <InsuranceSvcRq>
        #   <RenterPolicyQuoteInqRq>
        #     <MSI_CommunityAddressRq>
        #       <MSI_CommunityID>27254</MSI_CommunityID>
        #     </MSI_CommunityAddressRq>
        #   </RenterPolicyQuoteInqRq>
        # </InsuranceSvcRq>
        received = request.body.read
        doc = Nokogiri::XML(received)
        msi_id = doc.xpath("//MSI_CommunityID").text
        community = CarrierInsurableProfile.where(carrier_id: 5, external_carrier_id: msi_id.to_s).take&.insurable
        @units = community&.units&.order("title ASC") || []
        
        #puts msi_id
        
        #puts doc.xpath("//Moose")
      
        #puts "Params: #{params}"
        #puts "Reqbod: #{received}"
        #puts "Nokogi: #{doc.xpath("//Moose").text}"
        #puts "----"
        #@units = []
      end
      
      
      
      def get_or_create_params
        params.permit(:address, :unit_title, :insurable_id, :insurable_type_id)
      end
      
            
      def get_or_create
        # get a valid address model if possible
        address = ::Address.from_string(params[:address])
        unless address.errors.blank?
          render json: standard_error(:invalid_address, 'Invalid address value', address.errors.full_messages),
                 status: 422
          return
        end
        # try to figure out unit title if applicable
        seeking_unit = (!get_or_create_params[:unit_title].blank? || !get_or_create_params[:insurable_id].blank? || !address.street_two.blank?) ? true : false
        unit_title = nil
        if seeking_unit
          unit_title = get_or_create_params[:unit_title]
          if unit_title.blank? && !address.street_two.blank?
            splat = address.street_two.gsub('#', ' ').gsub('.', ' ')
                                      .gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '')
                                      .split(" ").select do |strang|
                                        ![
                                          'apartment', 'apt', 'unit',
                                          'flat', 'room', 'office',
                                          'no', 'number'
                                        ].include?(strang.lcase)
                                      end
            if splat.size == 1
              unit_title = splat[0]
            end
          end
        end
        ###insurable_type_id = params[:insurable_type_id].to_i || (!address.street_two.blank? ? ::InsurableType.where(title: "Residential Community").take : ::InsurableType.where(title: "Residential Unit").take)

        # search for the insurable
        results = ::Insurable.references(:address).includes(:addresses).where({
          addresses: {
            primary: true, 
            street_number: address.street_number,
            street_name: address.street_name,
            city: address.city,
            state: address.state,
            zip_code: address.zip_code
          }
        })
        if results.blank?
          # no results
        end
        if seeking_unit
          if unit_title.
        else
        end
        
        
        
        results = ::Insurable.find_from_address(address, { enabled: true, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS }, allow_multiple: false)
        
        
        
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
      
        def view_path
          super + "/insurables"
        end
        
        def set_insurable
          @insurable = access_model(::Insurable, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Insurable)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.insurables
          end
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
        def msi_community_info_id
          
        
          params.require(:policy_application)
            .permit(policy_rates_attributes:      [:insurable_rate_id],
                    policy_insurables_attributes: [:insurable_id])
        end
        
    end
  end # module Public
end
