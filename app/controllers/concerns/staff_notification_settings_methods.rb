module StaffNotificationSettingsMethods
  extend ActiveSupport::Concern

  def index
    @notification_settings = current_staff.notification_settings
    render json: @notification_settings.to_json, status: :ok
  end

  def show
    render json: @notification_setting.to_json, status: :ok
  end

  def update
    if @notification_setting.update(notification_setting_params)
      render json: @notification_setting.to_json, status: :ok
    else
      render json: @notification_setting.errors, status: :unprocessable_entity
    end
  end

  private
  def notification_setting_params
    params.require(:notification_setting).permit(:enabled)
  end
end
