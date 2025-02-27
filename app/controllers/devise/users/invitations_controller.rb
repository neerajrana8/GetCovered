class Devise::Users::InvitationsController < Devise::InvitationsController
  before_action :resource_from_invitation_token, only: [:edit, :update]
  after_action :save_token_for_password_reset, only: [:update]

  def update
    @raw_invitation_token = accept_invitation_params[:invitation_token]

    if allow_to_use_invitation_token?
      self.resource = accept_resource
      self.resource.update!(password: accept_invitation_params[:password],
                          password_confirmation: accept_invitation_params[:password_confirmation])

      yield resource if block_given?

      if resource.errors.empty?
        if resource.class.allow_insecure_sign_in_after_accept
          resource.after_database_authentication
          update_auth_header
          resource.create_token

          sign_out(resource) if accept_invitation_params[:password_confirmation].present?

          create_acct_user

          resource.update(invitation_token: generate_invitation_token_secret)

          render json: { success: ['User updated.'] },
               status: :accepted
        else
          render json: { success: ['User not updated.'] },
               status: :not_modified
        end
      else
        resource.update(invitation_token: generate_invitation_token_secret)
        render json: { errors: resource.errors.full_messages },
             status: :unprocessable_entity
      end
    else
      render json: { errors: ['Token already been used'] },
             status: :unprocessable_entity
    end
  end

  private

  def allow_to_use_invitation_token?
    self.resource.invitation_accepted_at.nil? || self.resource.tokens.count < 2
  end

  def resource_from_invitation_token
    unless params[:invitation_token] && self.resource = resource_class.find_by_invitation_token(params[:invitation_token], true)
      render json: { errors: ['Invalid token.'] }, status: :not_acceptable
    end
  end

  def generate_invitation_token_secret
    Devise.token_generator.digest(resource_class, :invitation_token, @raw_invitation_token)
  end

  def create_acct_user
    acct = AccountUser.find_by(user_id: resource.id, account_id: resource.account_users.last&.account_id)
    acct.update(status: 'enabled') if acct.present? && acct.status != 'enabled'
  end

  def save_token_for_password_reset
    resource.update(invitation_token: generate_invitation_token_secret)
  end

  def accept_resource
    resource_class.accept_invitation!(accept_invitation_params)
  end

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
