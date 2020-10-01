class ChangeRequest < ApplicationRecord
  belongs_to :changeable, polymorphic: true, optional: :true
  belongs_to :requestable, polymorphic: true

  # belongs_to :staff

  # Enum Options
  enum customized_action: %i[decline approve pending]
  enum status: %i[in_progress approved failed]
end
