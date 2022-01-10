module StaffNotificationSettingsMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_notifyable
    before_action :set_notification_setting, except: :index
  end

  def index
    @notification_settings = @notifyable.notification_settings
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

  def set_notifyable
    @notifyable =
      if params[:notifyable_id].present? && params[:notifyable_type].present?
        notifyable = params[:notifyable_type].constantize.find(params[:notifyable_id])

        if permitted_notifyable?(notifyable)
          notifyable
        else
          render json: standard_error(:not_permitted_notifyable), status: :forbidden
        end
      else
        current_staff
      end
  end

  def set_notification_setting
    @notification_setting = @notifyable.notification_settings.find(params[:id])
  end

  def notification_setting_params
    params.require(:notification_setting).permit(:enabled)
  end
end
