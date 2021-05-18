# Lease model
# file: app/models/lease.rb

class Lease < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include RecordChange

  # Active Record Callbacks
  after_initialize :initialize_lease

  before_validation :set_type, unless: proc { |lease| lease.insurable.nil? }

  before_validation :set_reference, if: proc { |lease| lease.reference.nil? }

  after_commit :update_unit_occupation

  belongs_to :account

  belongs_to :insurable
  belongs_to :lease_type

  has_many :lease_users, inverse_of: :lease

  has_many :users, through: :lease_users

  has_many :histories, as: :recordable

  accepts_nested_attributes_for :lease_users, :users

  # Validations
  validates_presence_of :start_date, :end_date

  validate :start_date_precedes_end_date

  validate :lease_type_insurable_type
  # validates :type, presence: true,
  #  format: { with: /Residential|Commercial/, message: "must be Residential or Commercial" }

  # validate :lease_type_matches_unit_type_if_present,
  #  unless: Proc.new { |lease| lease.unit.nil? }

  # validate :policy_account_matches_lease_account,
  #  unless: Proc.new { |lease| lease.policy.nil? || lease.policy.account.nil? || account.nil? }

  # validate :unit_account_matches_lease_account,
  #  unless: Proc.new { |lease| lease.unit.nil? || account.nil? }

  # Allow use of .type without invoking STI

  scope :active, -> { where('? BETWEEN "start_date" AND "end_date"', Time.zone.now).where(status: %i[approved current]) }

  self.inheritance_column = nil

  enum status: %i[pending approved current expired rejected]

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
    end
  end

  # Lease.active?
  def active?
    range = start_date..end_date
    range === Time.current
  end

  # Lease.activate
  def activate
    if status == 'approved'
      update status: 'current'
      # update covered: true if unit.covered

      related_history = {
        data: {
          leases: {
            model: 'Lease',
            id: id,
            message: "Lease ##{id} activated"
          }
        },
        action: 'update_related'
      }

      related_records_list.each do |related|
        send(related)&.histories&.create(related_history)
      end

      unless covered
        # Create Coverage Required Notification Here...
      end

    end
  end

  # Lease.deactivate
  def deactivate
    if status == 'current'
      update status: 'expired'

      related_history = {
        data: {
          leases: {
            model: 'Lease',
            id: id,
            message: "Lease ##{id} deactivated"
          }
        },
        action: 'update_related'
      }

      related_records_list.each do |related|
        send(related)&.histories&.create(related_history)
      end

    end
  end

  def update_unit_occupation
    insurable.update(occupied: insurable.leases.active.present?)
  end

  def related_records_list
    %w[insurable account]
  end
  
  # Lease.primary_insurable
  
  def primary_user
    lease_user = lease_users.where(primary: true).take
    lease_user.user.nil? ? nil : lease_user.user  
  end
  
  private

  ## Initialize Lease
  def initialize_lease
    # self.type = self.unit.type unless self.unit.nil?
  end

  def set_type
    # self.type ||= unit.type
  end

  def start_date_precedes_end_date
    errors.add(:end_date, 'must come after start date') if start_date >= end_date
  end

  def lease_type_insurable_type
    errors.add(:lease_type, 'LeaseType must be available for InsurableType') unless lease_type.insurable_types.include?(insurable.insurable_type)
  end

  def lease_type_matches_unit_type_if_present
    errors.add(:type, 'must match the type of the leased property') if type != unit.type
  end

  def policy_account_matches_lease_account
    errors.add(:policy, 'must have same account as lease') if policy.account.id != account.id
  end

  def unit_account_matches_lease_account
    errors.add(:unit, 'must have same account as lease') if unit.parent_account.id != account.id
  end

  # History methods

  def related_classes_through
    %i[account insurable]
  end

  def related_create_hash(_relation, _related_model)
    {
      self.class.name.to_s.downcase.pluralize => {
        'model' => self.class.name.to_s,
        'id' => id,
        'message' => 'New lease application'
      }
    }
  end

  def set_reference
    return_status = false

    if reference.nil?

      loop do
        self.reference = "#{account&.call_sign}-#{rand(36**12).to_s(36).upcase}"
        return_status = true

        break unless Lease.exists?(reference: reference)
      end
    end

    return_status
  end
end
