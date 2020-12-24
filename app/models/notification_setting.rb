class NotificationSetting < ApplicationRecord
  USERS_NOTIFICATIONS = %w[upcoming_invoice update_credit_card].freeze

  belongs_to :notifyable, polymorphic: true # User, Staff or other object/person who can manipulate notifications

end
