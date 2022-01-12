# frozen_string_literal: true

class Staff < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  serialize :tokens

  include SetAsOwner
  include RecordChange
<<<<<<< GCV2-4135-ruby-rails-upgrade-to-latest-versions
  include DeviseTokenAuth::Concerns::User
=======
  include DeviseCustomUser
  include ElasticsearchSearchable
>>>>>>> master
  include SessionRecordable

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3 }

  enum current_payment_method: %w[none ach_unverified ach_verified card other],
       _prefix: true


  validate :proper_role
  validates :organizable, presence: true, unless: -> { super_admin? }

  # Active Record Callbacks
  after_initialize :initialize_staff
  after_create :set_first_as_primary_on_organizable
  after_create :set_permissions_for_agent
  after_create :build_notification_settings

  # belongs_to relationships
  # belongs_to :account, required: true

  belongs_to :organizable, polymorphic: true, required: false

  # has_many relationships
  has_many :histories, as: :recordable, class_name: 'History', foreign_key: :recordable_id

  has_many :assignments

  # has_one relationships
  has_one :profile, as: :profileable, autosave: true
  has_one :staff_permission

  has_many :reports, as: :reportable

  has_many :invoices, as: :invoiceable
  has_many :payment_profiles, as: :payer

  has_many :notification_settings, as: :notifyable

  scope :enabled, -> { where(enabled: true) }

  accepts_nested_attributes_for :profile, update_only: true
  accepts_nested_attributes_for :staff_permission, update_only: true

  def as_indexed_json(options = {})
    as_json(
      options.merge(
        only: %i[id email organizable_type organizable_id role created_at updated_at],
        include: :profile
      )
    )
  end

  # Override as_json to always include profile information
  def as_json(options = {})
    json = super(options.reverse_merge(include: :profile))
    json
  end

  # Override active_for_authentication? to prevent non-owners or non-enabled staff to authorize
  def active_for_authentication?
    super && (owner || enabled)
  end

  def getcovered_agent?
    organizable_type == 'Agency' && organizable_id == ::Agency::GET_COVERED_ID
  end

  private

  def history_blacklist
    %i[tokens sign_in_count current_sign_in_at last_sign_in_at]
  end

  def initialize_staff; end

  def proper_role
    errors.add(:role, 'must match organization type') if organizable_type == 'Agency' && role != 'agent'
    errors.add(:role, 'must match organization type') if organizable_type == 'Account' && role != 'staff'
  end

  def set_first_as_primary_on_organizable
    if organizable&.staff&.count&.eql?(1) || organizable&.staff&.count&.eql?(0)
      organizable.update staff_id: id
      update_attribute(:owner, true)
    end
  end

  def set_permissions_for_agent
    if role == 'agent'
      StaffPermission.create(staff: self)
    end
  end

  def build_notification_settings
    NotificationSetting::STAFFS_NOTIFICATIONS.each do |opt|
      self.notification_settings.create(action: opt, enabled: false)
    end
  end
  
  def switch_agency(new_agency_id) # can also pass an Agency instead of an id
    new_agency = new_agency_id.class == ::Agency ? new_agency_id : ::Agency.where(id: new_agency_id).take
    new_agency_id = new_agency.id if new_agency_id.class == ::Agency
    if new_agency.nil?
      self.errors.add(:agency, "must exist")
      return false
    elsif self.role != 'agent'
      self.errors.add(:role, "must be agent")
      return false
    end
    worked = false
    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless self.update(organizable: new_agency)
      raise ActiveRecord::Rollback unless self.staff_permission.update(global_agency_permission_id: new_agency.global_agency_permission.id, permissions: new_agency.global_agency_permission.permissions)
      worked = true
    end
    return worked ? self : false
  end
end
