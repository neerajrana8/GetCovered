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
  before_create :set_global_permissions
  after_create :set_first_as_primary_on_staff
  after_commit :set_first_as_owner, on: :create

  accepts_nested_attributes_for :global_permission, update_only: true

  private

  def set_first_as_owner
    if role != 'super_admin' and organizable.staff.count === 1
      staff.update(owner: true)
    end
  end

  def set_global_permissions
    self.global_permission_attributes = {
      permissions: organizable.global_permission.permissions
    } unless super_admin? || policy_support?
  end

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
end
