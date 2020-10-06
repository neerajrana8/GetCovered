module PoliciesMethods
  extend ActiveSupport::Concern

  def update
    if @policy.update_as(current_staff, policy_application_merged_attributes)
      if update_user_params[:users].is_a? Array
        update_user_params[:users].each do |user_param|
          user = User.find_by(id: user_param[:id])
          user.update_attributes(user_param)
        end
      end
      render :show, status: :ok
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def create
    @policy = Policy.new(create_params)
    if @policy.save_as(current_staff)
      Insurables::UpdateCoveredStatus.run!(insurable: @policy.primary_insurable) if @policy.primary_insurable.present?
      render :show, status: :created
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  def add_coverage_proof
    @policy = Policy.new(coverage_proof_params)
    @policy.policy_in_system = false
    if @policy.save
      user_params[:users]&.each do |user_params|
        user = ::User.find_by(email: user_params[:email])
        if user.nil?
          user = ::User.new(user_params)
          user.password = SecureRandom.base64(12)
          if user.save
            user.invite!
          end
        end
        @policy.users << user
      end

      render json: { message: 'Policy created' }, status: :created
    else
      render json: { message: 'Policy failed' }, status: :unprocessable_entity
    end
  end

  def update_coverage_proof
    update_coverage_params = create_params
    documents_params = update_coverage_params.delete(:documents)
    if @policy.update_as(current_staff, update_coverage_params)
      user_params[:users]&.each do |user_params|
        user = ::User.find_by(email: user_params[:email])
        user.update_attributes(user_params)
      end
      if documents_params.present?
        @policy.documents.attach(documents_params)
      end

      render json: { message: 'Policy updated' }, status: :created
    else
      render json: { message: 'Policy failed' }, status: :unprocessable_entity
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
        policy_insurables_attributes: [ :insurable_id ],
        policy_users_attributes: [ :user_id ],
        policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                                       :limit, :deductible, :enabled, :designation ],
        policy_application_attributes: [fields: {}],
    )
  end

  def update_user_params
    params.require(:policy).permit(users: [:id, :email,
      address_attributes: [ :city, :country, :state, :street_name,
                            :street_two, :zip_code],
      profile_attributes: [ :first_name, :last_name, :contact_phone,
                            :birth_date, :gender, :salutation]]
    )
  end

  def user_params
    params.permit(users: [:primary,
                          :email, :agency_id, profile_attributes: [:birth_date, :contact_phone,
                                                                   :first_name, :gender, :job_title, :last_name, :salutation],
                          address_attributes: [ :city, :country, :state, :street_name,
                                                :street_two, :zip_code] ]
    )
  end

  def coverage_proof_params
    params.require(:policy).permit(:number,
                                   :account_id, :agency_id, :policy_type_id,
                                   :carrier_id, :effective_date, :expiration_date,
                                   :out_of_system_carrier_title, :address, documents: [],
                                   policy_users_attributes: [ :user_id ]
    )
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
        status: %i[scalar like],
        created_at: %i[scalar like],
        updated_at: %i[scalar like],
        policy_in_system: %i[scalar like],
        effective_date: %i[scalar like],
        expiration_date: %i[scalar like],
        users: {
            id: %i[scalar array],
            email: %i[scalar like],
            profile: {
                full_name: %i[scalar like],
            }
        }
    }
  end

  def create_params
    return({}) if params[:policy].blank?
    to_return = params.require(:policy).permit(
        :account_id, :agency_id, :auto_renew, :cancellation_reason,
        :cancellation_date, :carrier_id, :effective_date, :out_of_system_carrier_title,
        :expiration_date, :number, :policy_type_id, :status,
        documents: [],
        policy_insurables_attributes: [ :insurable_id ],
        policy_users_attributes: [ :user_id ],
        policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                                       :limit, :deductible, :enabled, :designation ]
    )
    return(to_return)
  end

  def supported_orders
    supported_filters(true)
  end
end
