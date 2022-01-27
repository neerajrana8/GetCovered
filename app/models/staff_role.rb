# frozen_string_literal: true

class StaffRole < ApplicationRecord
  # belongs_to relations
  belongs_to :staff
  belongs_to :organizable, polymorphic: true, required: false

  # has_one relations
  has_one :global_permission, as: :ownerable

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3, policy_support: 4 }

  # validations
  validate :proper_role
  validates :organizable, presence: true, unless: -> { super_admin? || policy_support? }

  # callbacks
  after_create :set_first_as_primary_on_staff
  after_create :create_permissions

  accepts_nested_attributes_for :global_permission, update_only: true

  private

  def proper_role
    errors.add(:role, 'must match organization type') if organizable_type == 'Agency' && role != 'agent'
    errors.add(:role, 'must match organization type') if organizable_type == 'Account' && role != 'staff'
  end

  def set_first_as_primary_on_staff
    if staff&.staff_roles.count.eql?(1)
      update_attribute(:primary, true)
      update_attribute(:active, true)
    end
  end

  def create_permissions
    if !self.global_permission and role === 'agent'
      permissions = self.organizable&.global_permission&.permissions || {}
      GlobalPermission.create(ownerable: self, permissions: permissions)
    end
  end
end
