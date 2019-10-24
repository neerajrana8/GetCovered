class Devise::Staffs::InvitationsController < Devise::InvitationsController
  # include InvitableMethods
  before_action :authenticate_staff!, only: :create
  before_action :resource_from_invitation_token, only: [:edit, :update]

  def create
    Staff.invite!(invite_params, current_staff)
    render json: { success: ['Staff created.'] }, 
           status: :created
  end

  def edit
    # redirect_to "#{client_api_url}?invitation_token=#{params[:invitation_token]}"
  end

  def update
    @staff.update(password: accept_invitation_params[:password], password_confirmation: accept_invitation_params[:password_confirmation])
    @staff.accept_invitation!
    if @staff.errors.empty?
      @staff.confirm
      render json: { success: ['Staff updated.'] }, 
             status: :accepted
    else
      render json: { errors: @staff.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private  

    def invite_params
      params.permit(staff: [:email, :invitation_token, :provider, :skip_invitation ])
    end

    def accept_invitation_params
      params.permit(:email, :password, 
                    :password_confirmation, 
                    :invitation_token, 
                    profile_attributes: [:first_name, :last_name, :contact_phone])
    end
end
