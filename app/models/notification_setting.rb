class NotificationSetting < ApplicationRecord
  USERS_NOTIFICATIONS = %w[upcoming_invoice update_credit_card rent_guarantee_warnings].freeze
  STAFFS_NOTIFICATIONS = %w[purchase].freeze

  belongs_to :notifyable, polymorphic: true # User, Staff or other object/person who can manipulate notifications
end
