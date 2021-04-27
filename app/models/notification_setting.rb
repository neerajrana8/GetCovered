class NotificationSetting < ApplicationRecord
  USERS_NOTIFICATIONS = %w[upcoming_invoice update_credit_card rent_guarantee_warnings].freeze
  STAFFS_NOTIFICATIONS = %w[purchase cancellation_request cancelled expired renewed].freeze

  belongs_to :notifyable, polymorphic: true # User, Staff or other object/person who can manipulate notifications

  def self.fix_staff_notification_settings
    Staff.find_each do |staff|
      NotificationSetting::STAFFS_NOTIFICATIONS.each do |notification|
        staff.notification_settings.create(action: notification, enabled: false) unless staff.notification_settings.exists?(action: notification)
      end
    end
  end

  def self.fix_user_notification_settings
    User.find_each do |user|
      NotificationSetting::USERS_NOTIFICATIONS.each do |notification|
        user.notification_settings.create(action: notification, enabled: false) unless user.notification_settings.exists?(action: notification)
      end
    end
  end
end
