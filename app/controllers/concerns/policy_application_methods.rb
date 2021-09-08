module PolicyApplicationMethods
  extend ActiveSupport::Concern

  def new
    selected_policy_type = params[:policy_type].blank? ? 'residential' : params[:policy_type]

    if valid_policy_types.include?(selected_policy_type)
      policy_type = PolicyType.find_by_slug(selected_policy_type)

      if selected_policy_type == "residential"
        agency_id    = defined?(@bearer) ? @bearer : new_residential_params[:agency_id].to_i
        account_id   = new_residential_params[:account_id].to_i
        insurable_id = ((new_residential_params[:policy_insurables_attributes] || []).first || { id: nil })[:id]
        insurable    = nil
        insurable    = Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS, enabled: true).take
        if insurable.nil?
          render(json: standard_error(:unit_not_found, I18n.t('policy_application_contr.new.unit_not_found')), status: :unprocessable_entity) and return
        end
        # fix up account and agency if needed
        account_id = insurable.account_id if account_id.nil?
        agency_id = insurable.agency_id || insurable.account&.agency_id if agency_id.nil?
        # get the carrier_id MOOSE WARNING: eventually, use account/agency and state to determine which to select
        cip = insurable.carrier_insurable_profiles.where(carrier_id: [::MsiService.carrier_id, ::QbeService.carrier_id]).order('created_at DESC').limit(1).take
        carrier_id = cip&.carrier_id || MsiService.carrier_id
        @preferred = (insurable.get_carrier_status(carrier_id) == :preferred)
      elsif selected_policy_type == "commercial"
        carrier_id = 3
      elsif selected_policy_type == 'rent-guarantee'
        carrier_id = 4
      elsif selected_policy_type == 'security-deposit-replacement'
        carrier_id = DepositChoiceService.carrier_id
      end

      carrier = Carrier.find(carrier_id)

      @application = PolicyApplication.new(policy_type: policy_type, carrier: carrier, agency_id: agency_id, account_id: account_id)
      @application.build_from_carrier_policy_type
      # MOOSE WARNING ARRAYHACK
      if  @application.coverage_selections
        @application.coverage_selections = @application.coverage_selections.map{|uid, datum| datum.merge({ 'uid' => datum }) }
      end
      @primary_user = ::User.new
      @application.users << @primary_user
    else
      render json:   standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')),
             status: :unprocessable_entity
    end
  end

  def create
    case params[:policy_application][:policy_type_id]
    when 1
      create_residential
    else
      unsupported_policy_type()
    end
  end

  def create_residential
    render json: { message: "Whoops, something went wrong!"}.to_json,
           status: :ok
  end

  def unsupported_policy_type
    render json: standard_error(:invalid_policy_type, "The selected policy is type is not yet supported by the Get Covered SDK"), status: 422
  end

  def get_coverage_options
    case (get_coverage_options_params[:carrier_id] || MsiService.carrier_id).to_i # we set the default to MSI for now since the form doesn't require a carrier_id input yet for this request
      when QbeService.carrier_id
        residential_get_coverage_options((get_coverage_options_params[:carrier_id] || MsiService.carrier_id).to_i)
      when MsiService.carrier_id
        residential_get_coverage_options((get_coverage_options_params[:carrier_id] || MsiService.carrier_id).to_i)
      when DepositChoiceService.carrier_id
        deposit_choice_get_coverage_options
      else
        render json:   { error: "#{I18n.t('policy_application_contr.get_coverage_options.invalid_combination')} #{get_coverage_options_params[:carrier_id] || 'NULL'}/#{get_coverage_options_params[:policy_type_id] || 'NULL'}" },
               status: :unprocessable_entity
    end
  end

  def deposit_choice_get_coverage_options
    @residential_unit_insurable_type_id = 4
    # validate params
    inputs = deposit_choice_get_coverage_options_params
    if inputs[:insurable_id].nil?
      render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.insurable_id_cannot_be_blank') },
             status: :unprocessable_entity
      return
    end
    if inputs[:effective_date].nil?
      render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.effective_date_cannot_be_blank') },
             status: :unprocessable_entity
      return
    end
    # pull unit from db
    unit = Insurable.where(id: inputs[:insurable_id].to_i).take
    if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
      render json:   { error: I18n.t('policy_application_contr.new.unit_not_found') },
             status: :unprocessable_entity
      return
    end
    # get coverage options
    result = unit.dc_get_rates(Date.parse(inputs[:effective_date]))
    unless result[:success]
      render json:   { error: "#{ I18n.t('policy_application_contr.deposit_choice_get_coverage_options.no_security_deposit_replacement')} #{result[:event]&.id || 0})" },
             status: :unprocessable_entity
      return
    end
    render json: { coverage_options: result[:rates] },
           status: 200
  end
  
  def qbe_get_coverage_options
    render json:   { error: "Under construction" },
           status: :unprocessable_entity
  end

  def residential_get_coverage_options(carrier_id)
    @residential_community_insurable_type_id = 1
    @residential_unit_insurable_type_id      = 4
    @ho4_policy_type_id                      = 1
    # grab params and validate 'em
    inputs = residential_get_coverage_options_params
    # define agency after inputs to solve error
    @agency_id                               = instance_variable_defined?(:@bearer) ? @bearer.id : inputs["agency_id"]
    if inputs[:insurable_id].nil?
      render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.insurable_id_cannot_be_blank') },
             status: :unprocessable_entity
      return
    end
    if inputs[:estimate_premium]
      if @agency_id.nil?
        render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.agency_cannot_be_blank') },
               status: :unprocessable_entity
        return
      end
      if inputs[:effective_date].nil?
        render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.effective_date_cannot_be_blank') },
               status: :unprocessable_entity
        return
      else
        begin
          Date.parse(inputs[:effective_date])
        rescue ArgumentError
          render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.effective_date_must_be_valid_date') },
                 status: :unprocessable_entity
          return
        end
      end
      if inputs[:additional_insured].nil?
        render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.additional_insured_cannot_be_blank') },
               status: :unprocessable_entity
        return
      end
      if inputs[:billing_strategy_id].nil?
        render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.billing_strategy_id_cannot_be_blank') },
               status: :unprocessable_entity
        return
      end
    end
    # pull unit from db
    unit = Insurable.where(id: inputs[:insurable_id].to_i).take
    if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
      render json:   { error: I18n.t('policy_application_contr.new.unit_not_found') },
             status: :unprocessable_entity
      return
    end
    # grab community
    community = unit.parent_community
    preferred = (unit.get_carrier_status(carrier_id) == :preferred)
    if community.nil?
      render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.community_not_found') },
             status: :unprocessable_entity
      return
    end
    # grab billing strategy and make sure it's valid
    billing_strategy      = BillingStrategy.where(carrier_id: carrier_id, agency_id: @agency_id.to_i, policy_type_id: @ho4_policy_type_id, id: inputs[:billing_strategy_id].to_i).take
    if billing_strategy.nil?
      render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.billing_strategy_must_belong_to_carrier') },
             status: :unprocessable_entity
      return
    end
    # get a bit of extra nonsense
    carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: @ho4_policy_type_id).take
    # MOOSE WARNING ARRAYHACK
    coverage_selections = inputs[:coverage_selections]
    if coverage_selections.class == ::Array
      coverage_selections = coverage_selections.map{|datum| [datum['uid'], datum] }.to_h
    end
    # get coverage options
    results = ::InsurableRateConfiguration.get_coverage_options(
      carrier_policy_type, unit, coverage_selections, inputs[:effective_date] ? Date.parse(inputs[:effective_date]) : nil, inputs[:additional_insured].to_i, billing_strategy,
      **({
          # execution options
          eventable: unit,
          perform_estimate: inputs[:estimate_premium] ? true : false,
          # overrides
          agency: Agency.where(id: residential_get_coverage_options_params[:agency_id].to_i || 0).take,
        }.merge(
          residential_get_coverage_options_params[:account_id].blank? ? {} : { account: Account.where(id: residential_get_coverage_options_params[:account_id]).take }
        ).merge(preferred ? {} : {
          nonpreferred_final_premium_params: {
            number_of_units: inputs[:number_of_units].to_i == 0 ? nil : inputs[:number_of_units].to_i,
            years_professionally_managed: inputs[:years_professionally_managed].blank? ? nil : inputs[:years_professionally_managed].to_i,
            year_built: inputs[:year_built].to_i == 0 ? nil : inputs[:year_built].to_i,
            gated: inputs[:gated].nil? ? nil : inputs[:gated] ? true : false
          }.compact
        })
      )
    )
    results[:coverage_options] = results[:coverage_options].map{|uid,sel| sel.merge({ 'uid' => uid }) } # MOOSE WARNING ARRAYHACK
    keys_to_keep = [:valid, :coverage_options, :estimated_premium, :estimated_installment, :estimated_first_payment, :installment_fee]
    response_tr = results.select{|k, v| keys_to_keep.include?(k) }.merge(results[:errors] ? { estimated_premium_errors: [results[:errors][:external]].flatten } : {})
    use_translations_for_msi_coverage_options!(response_tr)

    render json: response_tr,
           status: 200
  end

  private

  def new_residential_params
    params.require(:policy_application)
        .permit(:branding_profile_id, :agency_id, :account_id, :policy_type_id,
                :address_string, :unit_title, # for non-preferred
                policy_insurables_attributes: [:id]) # for preferred
  end

  def valid_policy_types
    return ["residential", "commercial", "rent-guarantee", "security-deposit-replacement"]
  end
  
  def use_translations_for_msi_coverage_options!(response_tr)
    response_tr[:coverage_options].each do |coverage_opt|
      uid = coverage_opt["uid"]
      title = I18n.t("coverage_options.#{uid}_title")
      description = I18n.t("coverage_options.#{uid}_desc")
      coverage_opt["description"] = description unless description.include?('translation missing')
      coverage_opt["title"] = title unless description.include?('translation missing')
    end
  end
  
  def get_coverage_options_params
    params.permit(:carrier_id, :policy_type_id)
  end

  def deposit_choice_get_coverage_options_params
    params.permit(:insurable_id, :effective_date)
  end

  def residential_get_coverage_options_params
    params.permit(:insurable_id, :agency_id, :account_id, :billing_strategy_id,
                  :effective_date, :additional_insured,
                  :estimate_premium,
                  :number_of_units, :years_professionally_managed, :year_built, :gated, # nonpreferred stuff
                  coverage_selections: {}#[:uid, :selection, selection: [ :data_type, :value ]]
                 )
  end

end
