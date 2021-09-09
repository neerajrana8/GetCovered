module PoliciesMethods
  extend ActiveSupport::Concern

  def update
    if @policy.update_as(current_staff, policy_application_merged_attributes)
      if update_user_params[:users].is_a? Array
        update_user_params[:users].each do |user_param|
          user = ::User.find_by(id: user_param[:id])
          user.update_attributes(user_param)
        end
      end
      Policies::UpdateDocuments.run!(policy: @policy)
      render :show, status: :ok
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def create
    @policy = Policy.new(create_params)
    if @policy.save_as(current_staff)
      render :show, status: :created
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def add_coverage_proof
    @policy                  = Policy.new(coverage_proof_params)
    @policy.policy_in_system = false
    @policy.status           = 'BOUND'
    add_error_master_types(@policy.policy_type_id)
    if @policy.errors.blank? && @policy.save
      result = Policies::UpdateUsers.run!(policy: @policy, policy_users_params: user_params[:policy_users_attributes])

      if result.failure?
        render json: result.failure, status: 422
      else
        render :show, status: :created
      end
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def update_coverage_proof
    type_id = update_coverage_params[:policy_type_id]
    add_error_master_types(type_id) if type_id.present?
    if @policy.errors.blank? && @policy.update_as(current_staff, update_coverage_params)
      result = Policies::UpdateUsers.run!(policy: @policy, policy_users_params: user_params[:policy_users_attributes])

      if result.failure?
        render json: result.failure, status: 422
      else
        render :show, status: :ok
      end
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def add_policy_documents
    if @policy.in_system?
      render json: standard_error(:not_permitted, 'Cant change documents for in system policies'),
             status: :unprocessable_entity
    else
      params.permit(documents: [])[:documents].each do |file|
        @policy.documents.attach(file)
      end

      render :show, status: :ok
    end
  end

  def delete_policy_document
    document = @policy.documents.find(delete_policy_document_params[:document_id])
    if document.present?
      document.purge
      render json: { message: 'Policy Document successfully deleted' }, status: :ok
    else
      render json: { message: 'Policy Document not found' }, status: :unprocessable_entity
    end
  end

  def refund_policy
    error = @policy.cancel('manual_cancellation_with_refunds', Time.current.to_date.end_of_day)
    if !error.nil?
      render json: standard_error(:refund_policy_error, error, @policy.errors.full_messages)
    else
      Policies::CancellationMailer.
        with(policy: @policy, without_request: true).
        cancel_confirmation.
        deliver_later
      render :show, status: :ok
    end
  end

  def cancel_policy
    error = @policy.cancel('manual_cancellation_without_refunds', Time.current.to_date.end_of_day)
    if !error.nil?
      render json: standard_error(:cancel_policy_error, error, @policy.errors.full_messages)
    else
      Policies::CancellationMailer.
        with(policy: @policy, without_request: true).
        cancel_confirmation.
        deliver_later
      render :show, status: :ok
    end
  end

  def set_optional_coverages
    if @policy.carrier_id != MsiService.carrier_id || @policy.primary_insurable.nil? || @policy.primary_insurable.primary_address.nil?
      @optional_coverages = nil
    else
      results = ::InsurableRateConfiguration.get_coverage_options(
        @policy.carrier_id,
        @policy.primary_insurable&.primary_address,
        [{ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true }],
        nil,
        0,
        @policy.policy_premiums.last&.billing_strategy&.carrier_code,
        agency: @policy.agency,
        perform_estimate: false,
        eventable: @policy.primary_insurable,
        nonpreferred_final_premium_params: {
          number_of_units: 1,
          years_professionally_managed: nil,
          year_built: nil,
          gated: false
        }.compact
      )

      @optional_coverages = results[:coverage_options].select { |coverage| coverage['requirement'] == 'optional' }.map do |coverage|
        policy_coverage =
          @policy.coverages.detect { |policy_coverage| policy_coverage['designation'] == coverage['uid'] }

        {
          designation: coverage['uid'],
          title: coverage['title'],
          enabled: policy_coverage.present? ? policy_coverage['enabled'] : false,
          limit: policy_coverage.present? ? policy_coverage['limit'] : nil
        }
      end
    end
  end

  private

  def update_params
    return({}) if params[:policy].blank?

    params.require(:policy).permit(
      :account_id, :agency_id, :auto_renew, :cancellation_code,
      :cancellation_date_date, :carrier_id, :effective_date,
      :expiration_date, :number, :policy_type_id, :status, :out_of_system_carrier_title,
      documents: [],
      policy_insurables_attributes: [:insurable_id],
      policy_users_attributes: [:user_id],
      policy_coverages_attributes: %i[id policy_application_id policy_id
                                      limit deductible enabled designation],
      policy_application_attributes: [fields: {}, extra_settings: {}]
    )
  end

  def update_coverage_params
    return({}) if params[:policy].blank?

    permitted_params =
      params.require(:policy).permit(
        :effective_date, :expiration_date, :number, :status, :out_of_system_carrier_title,
        policy_coverages_attributes: %i[id limit title deductible enabled designation]
      )

    existed_ids = permitted_params[:policy_coverages_attributes]&.map { |coverage| coverage[:id] }

    unless existed_ids.nil? || existed_ids.compact.blank?
      (@policy.policy_coverages.pluck(:id) - existed_ids).each do |id|
        permitted_params[:policy_coverages_attributes] <<
          ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
      end
    end

    permitted_params
  end

  def update_user_params
    params.require(:policy).permit(users: [:id, :email,
                                           profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name salutation],
                                           address_attributes: %i[city county street_number state street_name street_two zip_code]])
  end

  def delete_policy_document_params
    params.permit(:document_id)
  end

  def user_params
    params.require(:policy).permit(
      policy_users_attributes: [
        :spouse, :primary,
        user_attributes: [
          :email,
          profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name salutation],
          address_attributes: %i[city county street_number state street_name street_two zip_code]
        ]
      ]
    )
  end

  def coverage_proof_params
    params.require(:policy).permit(:number, :status,
                                   :account_id, :agency_id, :policy_type_id,
                                   :carrier_id, :effective_date, :expiration_date, :out_of_system_carrier_title,
                                   :address,
                                   policy_insurables_attributes: %i[insurable_id primary],
                                   policy_coverages_attributes: %i[title limit deductible enabled designation],
                                   documents: [])
  end

  def add_error_master_types(type_id)
    @policy.errors.add(:policy_type_id, 'You cannot add or update coverage via master policy type') if [2, 3].include?(type_id)
  end

  def policy_application_merged_attributes
    @update_params = update_params
    if @update_params[:policy_application_attributes]
      if @update_params[:policy_application_attributes][:fields]
        @update_params[:policy_application_attributes] =
          @policy.policy_application.attributes.deep_merge(@update_params[:policy_application_attributes])
      else
        @update_params.delete(:policy_application_attributes)
      end
    end
    @update_params
  end

  def supported_filters(called_from_orders = false)
    @calling_supported_orders = called_from_orders
    {
      id: %i[scalar array],
      carrier: {
        id: %i[scalar array],
        title: %i[scalar like]
      },
      number: %i[scalar like],
      policy_type_id: %i[scalar array],
      status: %i[scalar like array],
      created_at: %i[scalar like],
      updated_at: %i[scalar like],
      policy_in_system: %i[scalar like],
      effective_date: %i[scalar like],
      expiration_date: %i[scalar like],
      policy_insurables: {
        insurable_id: %i[scalar array]
      },
      users: {
        id: %i[scalar array],
        email: %i[scalar like],
        profile: {
          full_name: %i[scalar like]
        }
      },
      agency_id: %i[scalar array]
    }
  end

  def create_params
    return({}) if params[:policy].blank?

    to_return = params.require(:policy).permit(
      :account_id, :agency_id, :auto_renew, :cancellation_reason,
      :cancellation_date, :carrier_id, :effective_date, :out_of_system_carrier_title,
      :expiration_date, :number, :policy_type_id, :status,
      documents: [],
      policy_insurables_attributes: [:insurable_id],
      policy_users_attributes: [:user_id],
      policy_coverages_attributes: %i[id policy_application_id policy_id
                                      limit deductible enabled designation]
    )
    to_return
  end

  def supported_orders
    supported_filters(true)
  end
end
