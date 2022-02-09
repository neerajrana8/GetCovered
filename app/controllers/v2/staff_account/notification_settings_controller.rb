##
# V2 StaffAccount Notification Settings Controller
# File: app/controllers/v2/staff_account/notification_settings_controller.rb

module V2
  module StaffAccount
    class NotificationSettingsController < StaffAccountController
      include StaffNotificationSettingsMethods

      private

      def permitted_notifyable?(notifyable)
        notifyable.is_a?(Account) && notifyable.owner == current_user
      end
    end
  end
end
