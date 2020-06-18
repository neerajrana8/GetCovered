class ChangeRequest < ApplicationRecord
  belongs_to :changeable, 
  polymorphic: true

  belongs_to :requestable, 
    polymorphic: true

  belongs_to :staff

  # Enum Options
  enum action: %i[send delete update create]
  enum status: %i[in_progress success error]
end
