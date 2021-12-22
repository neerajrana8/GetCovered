# frozen_string_literal: true

class StaffRole < ApplicationRecord
  # belongs_to relation
  belongs_to :staff
  belongs_to :organizable, polymorphic: true, required: false

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3, policy_support: 4 }

  # validations
  validate :proper_role
  validates :organizable, presence: true, unless: -> { super_admin? || policy_support? }

  private

  def proper_role
    errors.add(:role, 'must match organization type') if organizable_type == 'Agency' && role != 'agent'
    errors.add(:role, 'must match organization type') if organizable_type == 'Account' && role != 'staff'
  end
end
