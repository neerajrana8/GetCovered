module InvitableMethods
  extend ActiveSupport::Concern

  def authenticate_inviter!
    # use authenticate_staff! in before_action
  end

  def authenticate_staff!
    return if current_staff
    render json: {
      errors: ['Authorized staff only.']
    }, status: :unauthorized
  end

  def resource_class(m = nil)
    if m
      mapping = Devise.mappings[m]
    else
      mapping = Devise.mappings[resource_name] || Devise.mappings.values.first
    end
    mapping.to
  end

  def resource_from_invitation_token
    @staff = Staff.find_by_invitation_token(params[:invitation_token], true)
    return if params[:invitation_token] && @staff
    render json: { errors: ['Invalid token.'] }, status: :not_acceptable
  end
end
