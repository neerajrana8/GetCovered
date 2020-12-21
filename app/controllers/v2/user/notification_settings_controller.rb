module V2
  module User
    class NotificationSettingsController < UserController
      def index
        notification_settings = current_user.notification_settings.pluck(:action, :enabled).to_h

        result_json =
          NotificationSetting::USERS_NOTIFICATIONS.map do |action|
            {
              title: I18n.t("notification_settings.action.#{action}"),
              action: action,
              enabled: notification_settings[action].nil? ? true : notification_settings[action]
            }
          end
        render json: result_json
      end

      def switch
        notification_setting = current_user.notification_settings.find_by_action(params[:action])

        if notification_setting.present? && !notification_setting.enabled?
          notification_setting.destroy!
        elsif notification_setting.present? && notification_setting.enabled?
          notification_setting.update(enabled: false)
        else # if notification_setting doesnt exist, it's mean that is action is enabled, so create a setting with default enabled false
          notification_setting = current_user.notification_settings.create(action: params[:action])
        end

        if notification_setting.errors.any?
          render json: standard_error(:fee_cant_be_destroyed, nil, notification_setting.errors.full_messages),
                 status: :unprocessable_entity
        else
          render json: { success: true, message: 'Setting was switched' }
        end
      end
    end
  end
end
