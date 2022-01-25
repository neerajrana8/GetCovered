# Agency model
# file: app/models/agency.rb
#
# An agency is an entity capable of issuing insurance policies on behalf of an
# insurance Carrier.  The agency is managed by staff who have been assigned the
# Agency in their organizable relationship.

class Agency < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include SetSlug
  include SetCallSign
  include CoverageReport
  include EarningsReport
  include RecordChange

  # Active Record Callbacks
  after_initialize :initialize_agency
  before_validation :set_producer_code, on: :create
  after_create :check_permissions

  # belongs_to relationships
  belongs_to :agency,
    optional: true# has_many relationships
  has_many :agencies
  has_many :tracking_urls
  has_many :carrier_agencies
  has_many :carriers, through: :carrier_agencies
  has_many :carrier_agency_authorizations, through: :carrier_agencies

  has_many :accounts
  has_many :insurables, through: :accounts
  has_many :insurable_rates
  has_many :leases, through: :accounts
  has_many :insurable_rates
  has_many :staff_roles, as: :organizable
  has_many :staff, through: :staff_roles
  has_many :global_permissions, through: :staff_roles

  has_many :account_staff, through: :accounts, as: :organizable, source: :staff, class_name: 'Staff'
  has_many :policies
  has_many :claims, through: :policies
  has_many :invoices, through: :policies
  has_many :payments, through: :invoices

  has_many :policy_applications
  has_many :policy_quotes

  has_many :branding_profiles, as: :profileable

  has_many :commission_strategies, as: :recipient
  has_many :commissions, as: :recipient
  has_many :commission_items, through: :commissions

  has_many :billing_strategies

  has_many :fees, as: :ownerable

  has_many :events,
    as: :eventable

  has_many :addresses, as: :addressable, autosave: true

  has_many :reports, as: :reportable

  has_many :active_account_users, through: :accounts

  has_many :active_users, through: :active_account_users, source: :user

  has_many :histories, as: :recordable

  has_many :pages, dependent: :destroy

  has_many :leads

  has_many :access_tokens, as: :bearer

  has_many :integrations, as: :integratable

  has_many :insurable_rate_configurations, as: :configurer

  has_many :notification_settings, as: :notifyable

  # has_one relations
  has_one :global_agency_permission
  has_one :global_permission, as: :ownerable

  has_many :access_tokens,
           as: :bearer

  has_many :notification_settings, as: :notifyable

  has_many :integrations,
           as: :integratable

  has_many :insurable_rate_configurations,
           as: :configurer

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :global_agency_permission, update_only: true
  accepts_nested_attributes_for :global_permission, update_only: true

  scope :enabled, -> { where(enabled: true) }
  scope :sub_agencies, -> { where.not(agency_id: nil) }
  scope :main_agencies, -> { where(agency_id: nil) }

  # ActiveSupport +pluralize+ method doesn't work correctly for this word(returns staffs). So I added alias for it
  alias staffs staff
  alias parent_agency agency

  # Validations

  validates_presence_of :title, :slug, :call_sign
  validate :parent_agency_exist, on: [:create, :update]
  validate :agency_to_sub_disabled, on: :update
  validates :integration_designation, uniqueness: { allow_nil: true }

  GET_COVERED_ID = 1

  def self.get_covered
    Agency.find(GET_COVERED_ID)
  end

  def default_branding_profile
    branding_profiles.default.take
  end

  def owner
    staff.where(id: staff_id).take
  end

  def primary_address
    addresses.where(primary: true).take
  end

  def sub_agency?
    self.agency_id.present?
  end

  # Agent.provides(policy_type_id)
  # checks to see if agent is authorized for a policy type
  # in a state and zipcode
  #
  # Example:
  #   @agency = Agency.find(1)
  #   @agency.provides?(1, "CA")
  #   => true / false

  def offers_policy_type_in_region(args = {})
    result = false
    requirements_check = false

    opts = {
      carrier_id: nil,
      policy_type_id: nil,
      state: nil,
      zip_code: nil,
      plus_four: nil
    }.merge!(args)

    opts.keys.each do |k|
      unless k == :plus_four
        requirements_check = opts[k].nil? ? false : true
        break if requirements_check == false
      end
    end

    if requirements_check
      carrier = Carrier.find(opts[:carrier_id])
      if carrier.carrier_policy_types.exists?(policy_type_id: opts[:policy_type_id])
        carrier_availability = carrier.carrier_policy_type_availabilities.where(state: opts[:state], available: true).take
        agency_availability =
          carrier.
            carrier_agency_authorizations.
            joins(:carrier_agency).
            where(
              carrier_agencies: { agency_id: id },
              carrier_agency_authorizations: { state: opts[:state], available: true }
            ).take

        unless carrier_availability.nil? ||
               agency_availability.nil?

          result = carrier_availability.on_blacklist?(opts[:zip_code], opts[:plus_four]) &&
            agency_availability.on_blacklist?(opts[:zip_code], opts[:plus_four]) ? false : true
        end

      end
    end
    result
  end

  def first_agent
    if staff.enabled.any?
      'active'
    elsif staff.any?
      'inactive'
    else
      nil
    end
  end

  def commission_balance
    commission_deductions.map(&:unearned_balance).reduce(:+) || 0
  end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
  end

  def parent_agencies_ids
    @ids ||= Agency.main_agencies.pluck(:id)
  end

  def branding_url
    self.branding_profiles&.last&.formatted_url || I18n.t('agency_model.no_branding')
  end

  def set_producer_code
    loop do
      self.producer_code = rand(36**12).to_s(36).upcase
      break unless Agency.exists?(producer_code: producer_code)
    end
  end

  def get_ancestor_chain
    to_return = [self]
    selected = self.agency
    while !selected.nil?
      to_return.push(selected)
      selected = selected.agency
    end
    return to_return
  end

  private

  def initialize_agency
   # Blank for now...
  end

  def check_permissions
    if self.agency_id.nil?
      GlobalPermission.create(ownerable: self, permissions: GlobalPermission::AVAILABLE_PERMISSIONS)
    end
  end

  def set_producer_code
    loop do
      self.producer_code = rand(36**12).to_s(36).upcase
      break unless Agency.exists?(producer_code: producer_code)
    end
  end

  def parent_agency_exist
    unless self.agency_id.nil? || parent_agencies_ids.include?(self.agency_id)
      errors.add(:agency, I18n.t('agency_model.parent_id_incorrect'))
    end
  end

  def agency_to_sub_disabled
    errors.add(:agency, I18n.t('agency_model.agency_cannot_be_updated')) if parent_agencies_ids.include?(self.agency_id) &&
                                                                    parent_agencies_ids.include?(self.id)
  end

end
