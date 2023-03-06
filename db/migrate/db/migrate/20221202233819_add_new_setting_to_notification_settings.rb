class AddNewSettingToNotificationSettings < ActiveRecord::Migration[6.1]
  def up
    Staff.all.each do |staff|
      next if staff.notification_settings.find_by_action('external_policy_emails_copy')

      staff.notification_settings.create(action: 'external_policy_emails_copy', enabled: true)
    end
  end

  def down
    NotificationSetting.where(action: 'external_policy_emails_copy', notifyable_type: 'Staff').delete_all
  end
end
