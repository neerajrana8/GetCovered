module InsurablesMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_insurable,
                  only: [:show, :get_qbe_county_options, :set_qbe_county]
    before_action :set_master_policies, only: :show
    before_action :set_user_from_auth_token, only: :show, if: :user_param_presented?

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

  def get_qbe_county_options
    # get community and make sure we actually have a cip with county options
    @insurable = @insurable.parent_community unless ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(@insurable.insurable_type_id)
    cip = @insurable.carrier_profile(1)
    if cip.nil?
      unless insurable.account_id.nil? # really, this error  means "this guy is registered under an account but has no carrier profile for QBE"
        render json: standard_error("Carrier Error", I18n.t('insurables_controller.qbe.no_cip')),
               status: 422
        return
      end
      @insurable.create_carrier_profile(QbeService.carrier_id)
      cip = @insurable.carrier_profile(1)
    end
    unless cip.data&.[]("county_resolution")&.[]("available")
      @insurable.get_qbe_zip_code
      cip.reload
      unless cip.data&.[]("county_resolution")&.[]("available")
        # no counties available
        render json: standard_error("No County Available", I18n.t('insurables_controller.qbe.no_counties_available')),
               status: 422
        return
      end
    end
    # get the options
    options = cip&.data&.[]('county_resolution')&.[]('matches')&.map{|match| match['county'].titlecase }.uniq || []
    resolved = cip&.data&.[]('county_resolved')
    render json: { resolved: resolved, options: options },
      status: 200
  end

  def set_qbe_county
    @insurable = @insurable.parent_community unless ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(@insurable.insurable_type_id)
    cip = @insurable.carrier_profile(1)
    if cip.nil? || cip.data&.[]('county_resolution').nil?
      # ain't no qbe boyoz
      render json: standard_error("Carrier Error", I18n.t('insurables_controller.qbe.no_cip')),
             status: 422
      return
    elsif cip.data['county_resolved']
      # already resolved
      render json: standard_error("County Already Resolved", I18n.t('insurables_controller.qbe.county_already_resolved')),
             status: 422
      return
    else
      cip.data['county_resolution']['matches'].select!{|opt| opt['county'].chomp(" COUNTY").gsub(/[^a-z]/i, ' ') == (params[:county] || "").upcase.chomp(" COUNTY").gsub(/[^a-z]/i, ' ') } # just in case one is "Whatever County" and the other is just "Whatever", one has a dash and one doesn't, etc
      if cip.data['county_resolution']['matches'].length == 1
        cip.data['county_resolution']['selected'] = cip.data["county_resolution"]["matches"][0]['seq']
        cip.data['county_resolution']['county_resolved_on'] = Time.current.strftime("%m/%d/%Y %I:%M %p")
        cip.data['county_resolved'] = true
        unless cip.save
          # render save error :(
          render json: standard_error("Carrier Error", I18n.t('insurables_controller.qbe.cip_save_error')),
                 status: 422
          return
        end
      else
        # render invalid county selection error
        render json: standard_error("Invalid County", I18n.t('insurables_controller.qbe.invalid_county_selection_error')),
               status: 422
        return
      end
    end
    render json: { success: true },
      status: 200
  end

  def get_or_create
    #diagnostics = {}
    result = ::Insurable.get_or_create(**{ # WARNING: the 'county' option is not here because we don't want randos submitting wrong counties--we ask the FCC for counties now in an Address callback. BUT it is still an available input to this method for use in the terminal.
        address: get_or_create_params[:address],
        unit: get_or_create_params[:unit],
        insurable_id: get_or_create_params[:insurable_id].to_i == 0 ? nil : get_or_create_params[:insurable_id].to_i,
        create_if_ambiguous: get_or_create_params[:create_if_ambiguous],
        disallow_creation: (get_or_create_params[:allow_creation] != true),
        communities_only: get_or_create_params[:communities_only],
        titleless: get_or_create_params[:titleless] ? true : false,
        neighborhood: get_or_create_params[:neighborhood]
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
          results: [insurable_prejson(result, short_mode: get_or_create_params[:short] || false, agency_id: get_or_create_params[:agency_id], policy_type_id: get_or_create_params[:policy_type_id], carrier_id: get_or_create_params[:carrier_id])]
      }, status: 200
    when ::Array
      render json: {
          results_type: 'possible_match',
          results: result.map{|r| insurable_prejson(r, short_mode: get_or_create_params[:short] || false, agency_id: get_or_create_params[:agency_id], policy_type_id: get_or_create_params[:policy_type_id], carrier_id: get_or_create_params[:carrier_id]) }
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

  def set_master_policies
    if @insurable.unit?
      @master_policy_coverage =
          @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS).take
      @master_policy = @master_policy_coverage&.policy
    else
      @master_policy =
          @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
      @master_policy_coverage = nil
    end
  end

  def set_insurable_liabilities
    if @master_policy.primary_insurable.nil?
      @min_liability = 1000000
      @max_liability = 30000000
    else
      insurable = @master_policy.primary_insurable.parent_community
      account = insurable.account
      carrier_id = account.agency.providing_carrier_id(PolicyType::RESIDENTIAL_ID, insurable){|cid| (insurable.get_carrier_status(carrier_id) == :preferred) ? true : nil }
      carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
      uid = (carrier_id == ::MsiService.carrier_id ? '1005' : carrier_id == ::QbeService.carrier_id ? 'liability' : nil)
      liability_options = ::InsurableRateConfiguration.get_inherited_irc(carrier_policy_type, account, insurable).configuration['coverage_options']&.[](uid)&.[]('options')
      @max_liability = liability_options&.map{|opt| opt['value'].to_i }&.max
      @min_liability = liability_options&.map{|opt| opt['value'].to_i }&.min
    end

    if @min_liability.nil? || @min_liability == 0 || @min_liability == "null"
      @min_liability = 1000000
    end

    if @max_liability.nil? || @max_liability == 0 || @max_liability == "null"
      @max_liability = 30000000
    end
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
    params.permit(:address, :unit, :insurable_id, :create_if_ambiguous, :allow_creation, :communities_only, :titleless, :neighborhood, :short,
      # optional:
      :agency_id, :policy_type_id, :carrier_id
    )
  end

  def user_param_presented?
    params[:user_id].present?
  end

  def set_user_from_auth_token
    @user = access_model(::User, params[:user_id])
  end

  # output stuff with essentially the same format as in the Address search
  def insurable_prejson(
    ins,
    short_mode: false,
    agency_id: nil,
    policy_type_id: nil,
    carrier_id: nil,
    subcall: false
  )
    case ins
    when ::Insurable
      if carrier_id.nil?
        carrier_id = Agency.find(agency_id || ins.account&.agency_id || ins.agency_id || Agency.where(master_agency: true).take.id).
                     providing_carrier_id(policy_type_id || ::PolicyType::RESIDENTIAL_ID, ins){|carrier_id| (carrier_id == ::QbeService.carrier_id && ins.get_carrier_status(carrier_id) == :preferred) ? true : nil }
      end
      if ::InsurableType::RESIDENTIAL_UNITS_IDS.include?(ins.insurable_type_id)
        com = ins.parent_community unless short_mode
        preferred = (ins.get_carrier_status(carrier_id) == :preferred) unless short_mode
        return {
          id: ins.id, title: ins.title,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
        }.merge(short_mode ? {} : {
          enabled: ins.enabled, preferred_ho4: preferred,
          category: ins.category, primary_address: insurable_prejson(ins.primary_address, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id, subcall: true),
          community: insurable_prejson(com, short_mode: true, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id, subcall: true)
        }.compact)
      elsif ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(ins.insurable_type_id)
        preferred = (ins.get_carrier_status(carrier_id) == :preferred)
        return {
          id: ins.id, title: ins.title, enabled: ins.enabled, preferred_ho4: preferred,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
        }.merge(short_mode && short_mode != 'buildings' ? {} : {
          category: ins.category, primary_address: insurable_prejson(ins.primary_address, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id, subcall: true),
          buildings: preferred && ins.enabled ? ins.insurables.confirmed.where(insurable_type_id: ::InsurableType::RESIDENTIAL_BUILDINGS_IDS, enabled: true).order(title: :asc).map{|u| insurable_prejson(u, subcall: true, short_mode: short_mode == 'buildings' ? true : false, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id) } : nil,
          units: preferred && ins.enabled ? ins.insurables.confirmed.where(insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS, enabled: true).order(title: :asc).map{|u| insurable_prejson(u, subcall: true, short_mode: true, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id) } : nil
        }).compact
      elsif ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(ins.insurable_type_id)
        com = ins.parent_community
        preferred = (ins.get_carrier_status(carrier_id) == :preferred) unless short_mode
        return {
          id: ins.id, title: ins.title,
          account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id,
        }.merge(short_mode ? {} : {
          enabled: ins.enabled, preferred_ho4: preferred,
          category: ins.category, primary_address: insurable_prejson(ins.primary_address, subcall: true, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id),
          units: preferred && ins.enabled ? ins.units.confirmed.order(title: :asc).select{|u| u.enabled }.map{|u| insurable_prejson(u, subcall: true, short_mode: true, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id) } : nil, # WARNING: we don't bother recursing with short mode here
          community: subcall ? nil : insurable_prejson(com, short_mode: true, agency_id: agency_id, policy_type_id: policy_type_id, carrier_id: carrier_id, subcall: true)
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
