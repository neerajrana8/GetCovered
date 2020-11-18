module LoginActivitiesMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_user
  end

  def index
    @logins = @user.login_activities.active

    render template: 'v2/shared/login_activities/index.json.jbuilder'
  end

  def close_all_sessions
    client = request.headers.env["HTTP_CLIENT"]
    @user.tokens = {client => @user.tokens.delete(client)}
    if @user.save_as(@user)
      render json: { message: 'Sessions closed' }, status: :ok
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = (current_user || current_staff)
  end

end
