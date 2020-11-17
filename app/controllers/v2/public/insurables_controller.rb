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
      
      
      
            
      def get_or_create
        diagnostics = {}
        result = ::Insurable.get_or_create(**{
          address: get_or_create_params(:address),
          unit: get_or_create_params(:unit),
          insurable_id: get_or_create_params(:insurable_id).to_i == 0 ? nil : get_or_create_params(:insurable_id).to_i,
          create_if_ambiguous: create_if_ambiguous,
          disallow_creation: disallow_creation,
          communities_only: communities_only,
          diagnostics: diagnostics
          # Omitted params: created_community_title, account_id
        }.compact)
        case result
          when ::NilClass
            render json: {
              results_type: 'no_match',
              results: nil
            }, status: 200
          when ::Insurable
            render json: {
              results_type: 'confirmed_match',
              results: insurable_prejson(result)
            }, status: 200
          when ::Array
            render json: {
              results_type: 'possible_match',
              results: result.map{|r| insurable_prejson(r) }
            }, status: 200
          when ::Hash
            render json: standard_error(result[:error_type], result[:message], result[:details]),
              status: 422
        end
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
        
        def get_or_create_params
          params.permit(:address, :unit, :insurable_id, :create_if_ambiguous, :disallow_creation, :communities_only)
        end
        
        # output stuff with essentially the same format as in the Address search
        def insurable_prejson(ins, short_mode: false)
          if ::InsurableType::RESIDENTIAL_UNITS_IDS.include?(ins.insurable_type_id)
            com = ins.parent_community unless short_mode
            return {
              id: ins.id, title: ins.title,
              account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
            }.merge(short_mode ? {} : {
              enabled: ins.enabled, preferred_ho4: com&.preferred_ho4 || false,
              category: ins.category, addresses: ins.addresses,
              community: insurable_prejson(com, short_mode: true)
            }).compact
          elsif ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(ins.insurable_type_id)
            return {
              id: id, title: ins.title, enabled: ins.enabled, preferred_ho4: ins.preferred_ho4,
              account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
            }.merge(short_mode ? {} : {
              category: ins.category, addresses: ins.addresses,
              units: ins.preferred_ho4 ? ins.units.select{|u| u.enabled }.map{|u| { id: u.id, title: u.title } } : nil
            }).compact
          elsif ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(ins.insurable_type_id)
            com = ins.parent_community
            return {
              id: id, title: ins.title,
              account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id,
            }.merge(short_mode ? {} : {
              enabled: ins.enabled, preferred_ho4: com&.preferred_ho4 || false,
              category: ins.category, addresses: ins.addresses,
              units: com&.preferred_ho4 ? ins.units.select{|u| u.enabled }.map{|u| { id: u.id, title: u.title } } : nil, # WARNING: we don't bother recursing with short mode here
              community: insurable_prejson(com, short_mode: true)
            }).compact
          else
            nil
          end
        end
        
    end
  end # module Public
end
