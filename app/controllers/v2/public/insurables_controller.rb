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
