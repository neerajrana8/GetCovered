class Lead < ApplicationRecord
  belongs_to :user, optional: true
  has_one :profile, as: :profileable
  has_one :address, as: :addressable

  has_many :lead_events, dependent: :destroy

  accepts_nested_attributes_for :address, :profile, update_only: true
end
