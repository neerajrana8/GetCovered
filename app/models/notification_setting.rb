# == Schema Information
#
# Table name: notification_settings
#
#  id              :bigint           not null, primary key
#  action          :string
#  enabled         :boolean          default(FALSE), not null
#  notifyable_type :string
#  notifyable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class NotificationSetting < ApplicationRecord
  USERS_NOTIFICATIONS = %w[upcoming_invoice update_credit_card rent_guarantee_warnings].freeze
  STAFFS_NOTIFICATIONS = %w[purchase cancellation_request cancelled expired renewed daily_sales_report external_policy_emails_copy].freeze
  ACCOUNTS_NOTIFICATIONS = %w[daily_sales_report].freeze
  AGENCIES_NOTIFICATIONS = %w[daily_sales_report].freeze

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

  def self.fix_account_notification_settings
    Account.find_each do |account|
      NotificationSetting::ACCOUNTS_NOTIFICATIONS.each do |notification|
        account.notification_settings.create(action: notification, enabled: false) unless account.notification_settings.exists?(action: notification)
      end
    end
  end

  def self.fix_agency_notification_settings
    Agency.find_each do |agency|
      NotificationSetting::AGENCIES_NOTIFICATIONS.each do |notification|
        agency.notification_settings.create(action: notification, enabled: false) unless agency.notification_settings.exists?(action: notification)
      end
    end
  end
end
