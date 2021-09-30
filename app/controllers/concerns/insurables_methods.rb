module InsurablesMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_insurable,
                  only: [:show]

    before_action :set_substrate,
                  only: [:index]
  end

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
    @units = community&.units&.confirmed&.order("title ASC") || []
  end

  def get_or_create
    #diagnostics = {}
    result = ::Insurable.get_or_create(**{
        address: get_or_create_params[:address],
        unit: get_or_create_params[:unit],
        insurable_id: get_or_create_params[:insurable_id].to_i == 0 ? nil : get_or_create_params[:insurable_id].to_i,
        create_if_ambiguous: get_or_create_params[:create_if_ambiguous],
        disallow_creation: (get_or_create_params[:allow_creation] != true),
        communities_only: get_or_create_params[:communities_only],
        titleless: get_or_create_params[:titleless] ? true : false
        #, diagnostics: diagnostics
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
    params.permit(:address, :unit, :insurable_id, :create_if_ambiguous, :allow_creation, :communities_only, :titleless)
  end

  # output stuff with essentially the same format as in the Address search
  def insurable_prejson(ins, short_mode: false, carrier_id: ins.class != ::Insurable ? nil : ins.carrier_insurable_profiles.order("created_at desc").first&.carrier_id || MsiService.carrier_id)
    case ins
    when ::Insurable
      if ::InsurableType::RESIDENTIAL_UNITS_IDS.include?(ins.insurable_type_id)
        com = ins.parent_community unless short_mode
        preferred = (ins.get_carrier_status(carrier_id) == :preferred) unless short_mode
        return {
          id: ins.id, title: ins.title,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
        }.merge(short_mode ? {} : {
          enabled: ins.enabled, preferred_ho4: preferred,
          category: ins.category, primary_address: insurable_prejson(ins.primary_address),
          community: insurable_prejson(com, short_mode: true, carrier_id: carrier_id)
        }.compact)
      elsif ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(ins.insurable_type_id)
        preferred = (ins.get_carrier_status(carrier_id) == :preferred)
        return {
          id: ins.id, title: ins.title, enabled: ins.enabled, preferred_ho4: preferred,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
        }.merge(short_mode ? {} : {
          category: ins.category, primary_address: insurable_prejson(ins.primary_address),
          units: preferred && ins.enabled ? ins.units.confirmed.select{|u| u.enabled }.map{|u| insurable_prejson(u, short_mode: true, carrier_id: carrier_id) } : nil
        }).compact
      elsif ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(ins.insurable_type_id)
        com = ins.parent_community
        preferred = (ins.get_carrier_status(carrier_id) == :preferred) unless short_mode
        return {
          id: ins.id, title: ins.title,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id,
        }.merge(short_mode ? {} : {
          enabled: ins.enabled, preferred_ho4: preferred,
          category: ins.category, primary_address: insurable_prejson(ins.primary_address),
          units: ins.preferred && ins.enabled ? ins.units.confirmed.select{|u| u.enabled }.map{|u| insurable_prejson(u, short_mode: true, carrier_id: carrier_id) } : nil, # WARNING: we don't bother recursing with short mode here
          community: insurable_prejson(com, short_mode: true, carrier_id: carrier_id)
        }.compact)
      else
        return nil
      end
    when ::Address
      return {
        full: ins.full,
        street_number: ins.street_number, street_name: ins.street_name,
        street_two: ins.street_two,
        city: ins.city, state: ins.state, zip_code: ins.zip_code,
        county: ins.county, country: ins.country
      }
    else
      return nil
    end
  end

end
