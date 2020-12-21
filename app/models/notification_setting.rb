class NotificationSetting
  belongs_to :notifyable, polymorphic: true # User, Staff or other object/person who can manipulate notifications
end
