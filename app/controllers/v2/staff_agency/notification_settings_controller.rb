##
# V2 StaffAgency Notification Settings Controller
# File: app/controllers/v2/staff_agency/notification_settings_controller.rb

module V2
  module StaffAgency
    class NotificationSettingsController < StaffAgencyController
      include StaffNotificationSettingsMethods

      private

      def permitted_notifyable?(notifyable)
        notifyable.is_a?(Agency) && notifyable.owner == current_user
      end
    end
  end
end
