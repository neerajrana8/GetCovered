class LoginActivity < ApplicationRecord
  belongs_to :user, polymorphic: true, optional: true

  scope :active, -> {where(active: true).where('expiry > ?', Proc.new{Time.now.to_i}.call)}
end
