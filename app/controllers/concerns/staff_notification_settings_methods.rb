module StaffNotificationSettingsMethods
  extend ActiveSupport::Concern
  before_action :set_notification_setting, except: :index

  def index
    @notification_settings = current_staff.notification_settings
  end

  def show; end

  def update
    if @notification_setting.update(notification_setting_params)
      render :show, status: :ok
    else
      render json: @notification_setting.errors, status: :unprocessable_entity
    end
  end

  private
  def set_notification_setting
    @notification_setting = current_staff.notification_settings.find(:id)
  end

  def notification_setting_params
    params.require(:notification_setting).permit(:enabled)
  end
end
