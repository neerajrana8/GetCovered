module PoliciesMethods
  extend ActiveSupport::Concern

  def update
    binding.pry
    if @policy.update_as(current_staff, policy_application_merged_attributes)
      render :show, status: :ok
    else
      render json: @policy.errors, status: :unprocessable_entity
    end
  end

  private

  def update_params
    return({}) if params[:policy].blank?
    params.require(:policy).permit(
        :account_id, :agency_id, :auto_renew, :cancellation_code,
        :cancellation_date_date, :carrier_id, :effective_date,
        :expiration_date, :number, :policy_type_id, :status,
        documents: [],
        policy_insurables_attributes: [ :insurable_id ],
        policy_users_attributes: [ :user_id ],
        policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                                       :limit, :deductible, :enabled, :designation ],
        policy_application_attributes: [fields: {}]
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
end
