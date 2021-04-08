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
        # determine preferred status
        @preferred = (insurable.parent_community || insurable).preferred_ho4
        # get the carrier_id
        carrier_id = nil
        if @preferred
          # MOOSE WARNING: eventually, use account_id/agency_id to determine which to select when there are multiple
          cip        = insurable.carrier_insurable_profiles.where(carrier_id: policy_type.carrier_policy_types.map{|cpt| cpt.carrier_id }).order("created_at DESC").limit(1).take
          carrier_id = cip&.carrier_id
          if carrier_id.nil?
            render json:   { error: I18n.t('policy_application_contr.new.invalid_unit') },
                   status: :unprocessable_entity
            return
          end
        else
          carrier_id = 5
        end
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
      @primary_user = ::User.new
      @application.users << @primary_user
    else
      render json:   standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')),
             status: :unprocessable_entity
    end
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

end
