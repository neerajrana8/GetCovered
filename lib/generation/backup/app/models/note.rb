class Note < ApplicationRecord
  belongs_to :staff
  belongs_to :noteable, polymorphic: true
end
