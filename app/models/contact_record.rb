# frozen_string_literal: true

class ContactRecord < ApplicationRecord
  enum direction: { outgoing: 0, incoming: 1 }
  enum approach: { email: 0 }
  enum status: { in_progress: 0, sent: 1 }

  belongs_to :contactable, polymorphic: true, required: true
end
