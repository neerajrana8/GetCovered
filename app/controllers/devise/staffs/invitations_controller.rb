class Devise::Staffs::InvitationsController < Devise::InvitationsController
  include InvitableMethods
  before_action :authenticate_staff!, only: :create
  before_action :resource_from_invitation_token, only: [:update]

  def create
    Staff.invite!(invite_params, current_staff)
    render json: { success: ['Staff created.'] }, 
           status: :created
  end

  def update
    @staff.update(accept_invitation_params)
    @staff.accept_invitation!
    if @staff.errors.empty?
      @resource = @staff
      @token = @resource.create_token
      @resource.save!
      update_auth_header
      render json: { success: ['Staff updated.'] }, 
             status: :accepted
    else
      render json: { errors: @staff.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private  

    def invite_params
      params.permit(:email, :invitation_token, :provider, :skip_invitation)
    end

    def accept_invitation_params
      params.permit(:email, :password, 
                    :password_confirmation, 
                    :invitation_token, 
                    profile_attributes: [:first_name, :last_name, :contact_phone])
    end
end
