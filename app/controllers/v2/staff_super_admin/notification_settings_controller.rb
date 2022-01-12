##
# V2 StaffSuperAdmin Notification Settings Controller
# File: app/controllers/v2/staff_super_admin/notification_settings_controller.rb

module V2
  module StaffSuperAdmin
    class NotificationSettingsController < StaffSuperAdminController
      include StaffNotificationSettingsMethods

      private

      def permitted_notifyable?(_)
        true
      end
    end
  end
end
