class Users::InvitationsController < Devise::InvitationsController
  before_action :resource_from_invitation_token, only: [:edit, :update]

  def create
    User.invite!(invite_params)
    render json: { success: true }, 
           status: :created
  end

  def edit
    # redirect_to "#{client_api_url}?invitation_token=#{params[:invitation_token]}"
  end

  def update
    @user.update(password: accept_invitation_params[:password], password_confirmation: accept_invitation_params[:password_confirmation])
    @user.accept_invitation!
    if @user.errors.empty?
      @user.confirm
      render json: { success: ['User updated.'] }, 
             status: :accepted
    else
      render json: { errors: @user.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private  

    def invite_params
      params.permit(user: [:email, :invitation_token, :provider, :skip_invitation])
    end

    def accept_invitation_params
      params.permit(:email, :password, 
                    :password_confirmation, 
                    :invitation_token, 
                    profile_attributes: [:first_name, :last_name, :contact_phone, :birth_date])
    end
end
