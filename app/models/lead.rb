class Lead < ApplicationRecord
  belongs_to :user, optional: true
  has_many :lead_events, dependent: :destroy
end
