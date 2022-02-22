# frozen_string_literal: true

class Staff < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  serialize :tokens

  include SetAsOwner
  include RecordChange
  include DeviseCustomUser
  include ElasticsearchSearchable
  include SessionRecordable

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3 }

  enum current_payment_method: %w[none ach_unverified ach_verified card other],
       _prefix: true


  # validate :proper_role
  # validates :organizable, presence: true, unless: -> { super_admin? }

  # Active Record Callbacks
  after_initialize :initialize_staff
  after_create :set_first_as_primary_on_organizable
  after_create :build_notification_settings

  # belongs_to relationships
  # belongs_to :account, required: true

  belongs_to :organizable, polymorphic: true, required: false

  # has_many relationships
  has_many :histories, as: :recordable, class_name: 'History', foreign_key: :recordable_id

  has_many :assignments
  has_many :reports, as: :reportable
  has_many :invoices, as: :invoiceable
  has_many :payment_profiles, as: :payer
  has_many :notification_settings, as: :notifyable
  has_many :staff_roles, dependent: :destroy
  has_many :agencies, through: :staff_roles, source_type: 'Agency', source: :organizable
  has_many :accounts, through: :staff_roles, source_type: 'Account', source: :organizable

  # has_one relationships
  has_one :profile, as: :profileable, autosave: true
  has_one :staff_permission

  scope :enabled, -> { where(enabled: true) }

  accepts_nested_attributes_for :profile, update_only: true
  accepts_nested_attributes_for :staff_permission, update_only: true
  accepts_nested_attributes_for :staff_roles

  alias available_roles staff_roles

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :email, type: :text
      indexes :profile do
        indexes :id,   type: :long
        indexes :first_name, type: :text
        indexes :last_name, type: :text
        indexes :middle_name, type: :text
        indexes :title, type: :text
        indexes :suffix, type: :text
        indexes :full_name, type: :text
        indexes :contact_email, type: :text
        indexes :contact_phone, type: :text
      end
    end
  end

  def as_indexed_json(options = {})
    as_json(
      options.merge(
        only: %i[id email organizable_type organizable_id role created_at updated_at],
        include: :profile
      )
    )
  end

  def self.update_profile(profile, options = {})
    options[:index] ||= index_name
    options[:type]  ||= document_type
    options[:wait_for_completion] ||= false

    options[:body] = {
      conflicts: :proceed,
      query: {
        match: {
          'profile.id': profile.id
        }
      },
      script: {
        lang: :painless,
        source: 'ctx._source.profile.contact_phone = params.profile.contact_phone; ctx._source.profile.last_name = params.profile.last_name; ctx._source.profile.first_name = params.profile.first_name; ctx._source.profile.full_name = params.profile.full_name; ctx._source.profile.title = params.profile.title; ctx._source.profile.contact_email = params.profile.contact_email;',
        params: { profile: { contact_phone: profile.contact_phone, last_name: profile.last_name, first_name: profile.first_name, full_name: profile.full_name, title: profile.title, contact_email: profile.contact_email } }
      }
    }

    __elasticsearch__.client.update_by_query(options)
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
    self.staff_roles.where(organizable: 'Agency', organizable_id: ::Agency::GET_COVERED_ID).count > 0
  end

  def primary_role
    conditions = {
      primary: true
    }

    self.staff_roles.where(conditions).first
  end

  def current_role(organizable: nil)
    conditions = {
      active: true
    }

    if organizable
      conditions[:organizable_type] = organizable
    end

    self.staff_roles.where(conditions).first
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
    if organizable&.staff&.count&.eql?(1)
      organizable.update staff_id: id
      update_attribute(:owner, true)
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
