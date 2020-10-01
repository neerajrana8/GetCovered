class ChangeRequest < ApplicationRecord
  belongs_to :changeable, polymorphic: true
  belongs_to :requestable, polymorphic: true

  # belongs_to :staff

  # Enum Options
  enum customized_action: %i[decline approve pending]
  enum status: %i[in_progress pending approved failed]
end
