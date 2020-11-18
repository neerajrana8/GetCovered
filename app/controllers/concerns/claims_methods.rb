module ClaimsMethods
  extend ActiveSupport::Concern

  def create
    @claim = Claim.new(claim_params)
    @claim.claimant = current_staff
    if @claim.save_as(current_staff)
      render :show, status: :created
      ClaimSendJob.perform_later(current_staff, @claim.id)
    else
      render json: @claim.errors,
             status: :unprocessable_entity
    end
  end

  def process_claim
    if @claim.update_as(current_staff, process_params)
      render :show, status: :ok
    else
      render json: @claim.errors,
             status: :unprocessable_entity
    end
  end

  def update
    if @claim.update_as(current_staff, update_params)
      render :show,
             status: :ok
    else
      render json: @claim.errors,
             status: :unprocessable_entity
    end
  end

  private

  def claim_params
    return({}) if params[:claim].blank?

    to_return = params.require(:claim).permit(
        :description, :insurable_id, :policy_id, :subject,
        :time_of_loss, :type_of_loss, documents: []
    )
    to_return
  end

  def process_params
    return({}) if params[:claim].blank?

    to_return = params.require(:claim).permit(:status, :staff_notes)
    to_return
  end

  def update_params
    return({}) if params[:claim].blank?

    params.require(:claim).permit(
        :description, :insurable_id, :policy_id, :subject,
        :time_of_loss, :type_of_loss, :staff_notes, documents: []
    )
  end
end
