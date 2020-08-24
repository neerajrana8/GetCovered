module StaffsMethods
  extend ActiveSupport::Concern

  def re_invite
    if @staff.enabled?
      render json: { success: false, errors: { staff: 'Already activated' } }, status: :unprocessable_entity
    else
      if @staff.invite_as(current_staff)
        render json: { success: true }, status: :ok
      else
        render json: { success: false,
                       errors: { staff: 'Unable to re-invite Staff', rails_errors: @staff.errors.to_h } },
               status: :unprocessable_entity
      end
    end
  end
end
