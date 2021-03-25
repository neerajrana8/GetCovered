##
# V2 StaffAccount Notification Settings Controller
# File: app/controllers/v2/staff_account/notification_settings_controller.rb

module V2
  module StaffAccount
    class NotificationSettingsController < StaffAccountController
      include StaffNotificationSettingsMethods
      before_action :set_notification_setting, except: :index

      private
      def set_notification_setting
        @notification_setting = current_staff.notification_settings.find(:id)
      end
    end
  end
end
