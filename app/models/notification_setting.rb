class NotificationSetting
  USERS_NOTIFICATIONS = %w[upcoming_invoice update_credit_card warning_emails].freeze

  belongs_to :notifyable, polymorphic: true # User, Staff or other object/person who can manipulate notifications

end
