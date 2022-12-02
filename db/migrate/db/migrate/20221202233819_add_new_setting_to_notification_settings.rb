class AddNewSettingToNotificationSettings < ActiveRecord::Migration[6.1]
  def up
    Staff.all.each do |staff|
      next if staff.notification_settings.find_by_action('send_external_related_emails_to_pms')

      staff.notification_settings.create(action: 'send_external_related_emails_to_pms', enabled: false)
    end
  end

  def down
    NotificationSetting.where(action: 'send_external_related_emails_to_pms', notifyable_type: 'Staff').delete_all
  end
end
