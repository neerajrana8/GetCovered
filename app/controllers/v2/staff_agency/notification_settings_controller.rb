##
# V2 StaffAgency Notification Settings Controller
# File: app/controllers/v2/staff_agency/notification_settings_controller.rb

module V2
  module StaffAgency
    class NotificationSettingsController < StaffAgencyController
      include StaffNotificationSettingsMethods
      before_action :set_notification_setting, except: :index

      private
      def set_notification_setting
        @notification_setting = current_staff.notification_settings.find(:id)
      end
    end
  end
end
