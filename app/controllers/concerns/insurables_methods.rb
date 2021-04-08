module InsurablesMethods
  extend ActiveSupport::Concern

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
        address: get_or_create_params[:address],
        unit: get_or_create_params[:unit],
        insurable_id: get_or_create_params[:insurable_id].to_i == 0 ? nil : get_or_create_params[:insurable_id].to_i,
        create_if_ambiguous: get_or_create_params[:create_if_ambiguous],
        disallow_creation: (get_or_create_params[:allow_creation] != true),
        communities_only: get_or_create_params[:communities_only],
        titleless: get_or_create_params[:titleless] ? true : false,
        diagnostics: diagnostics
    }.compact)
    case result
    when ::NilClass
      render json: {
          results_type: 'no_match',
          results: []
      }, status: 200
    when ::Insurable
      render json: {
          results_type: 'confirmed_match',
          results: [insurable_prejson(result)]
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

end
