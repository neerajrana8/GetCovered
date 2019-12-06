module V2
  # This controller checks: the gotten email is used or not.
  class CheckEmailController < V2Controller
    def user
      render json: { email_available_to_use: check_email(::User) }
    end

    def staff
      render json: { email_available_to_use: check_email(::Staff) }
    end

    private

    def check_email(model)
      if users_email(model)
        true
      else
        !model.exists?(uid: params[:email])
      end
    end

    # if :id is passed in the params, trying to find a user with this :id and :email, if it
    # exists, so this email can be used
    def users_email(model)
      model.exists?(id: params[:id], uid: params[:email]) if params[:id].present?
    end
  end
end
