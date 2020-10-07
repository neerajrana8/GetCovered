class ChangeRequest < ApplicationRecord
  belongs_to :changeable, polymorphic: true
  belongs_to :requestable, polymorphic: true

  # belongs_to :staff

  # Enum Options
  enum customized_action: %i[decline approve pending cancel]
  enum status: %i[awaiting_confirmation in_progress approved failed declined]
end
