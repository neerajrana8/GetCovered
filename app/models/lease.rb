# == Schema Information
#
# Table name: leases
#
#  id               :bigint           not null, primary key
#  reference        :string
#  start_date       :date
#  end_date         :date
#  status           :integer          default("pending")
#  covered          :boolean          default(FALSE)
#  lease_type_id    :bigint
#  insurable_id     :bigint
#  account_id       :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  expanded_covered :jsonb
#  defunct          :boolean          default(FALSE), not null
#
# Lease model
# file: app/models/lease.rb

class Lease < ApplicationRecord
  # Concerns
  include RecordChange
  include ExpandedCovered
  include SpecialStatusable

  RESIDENTIAL_ID = 1
  COMMERCIAL_ID = 2

  # Active Record Callbacks
  after_initialize :initialize_lease

  before_validation :set_type, unless: proc { |lease| lease.insurable.nil? }

  before_validation :set_reference, if: proc { |lease| lease.reference.nil? }

  after_commit :update_status,
               if: Proc.new{ saved_change_to_start_date? || saved_change_to_end_date? }

  after_commit :update_unit_occupation
  after_commit :update_users_status

  belongs_to :account

  belongs_to :insurable
  belongs_to :lease_type

  has_many :policies,
           through: :insurable

  #TODO: need to be discussed and updated after GCVR2-1018
  has_many :lease_users#, -> { where('moved_in_at <= ?', Time.current).where('moved_out_at >= ?', Time.current) }, inverse_of: :lease

  has_many :users, through: :lease_users

  has_many :histories, as: :recordable

  has_many :integration_profiles,
           as: :profileable

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

  self.inheritance_column = nil

  enum status: %i[pending current expired]

  enum special_status: SPECIAL_STATUSES,
    _prefix: true

  scope :current, -> { where(status: 'current') }

  # Lease.active?
  def active?
    range = start_date..end_date
    range === Time.current
  end
  
  
  def active_lease_users(present_date = Time.current.to_date, lessee: [true, false], allow_future: nil, lease_user_where: nil)
    allow_future = (self.status == 'pending') if allow_future.nil?
    if allow_future
      return(
        self.lease_users.where(moved_out_at: nil)
          .or(self.lease_users.where(moved_out_at: (present_date...)))
          .send(*(lease_user_where ? [:where, lease_user_where] : [:itself]))
          .where(lessee: lessee) 
      )
    end
    self.lease_users.where(moved_out_at: nil, moved_in_at: nil)
        .or(self.lease_users.where(moved_out_at: nil).where("moved_in_at <= ?", present_date))
        .or(self.lease_users.where(moved_out_at: (present_date...), moved_in_at: nil))
        .or(self.lease_users.where(moved_out_at: (present_date...)).where("moved_in_at <= ?", present_date))
        .send(*(lease_user_where ? [:where, lease_user_where] : [:itself]))
        .where(lessee: lessee) 
  end
  
  def active_users(present_date = Time.current.to_date, lessee: [true, false], allow_future: nil, lease_user_where: nil)
    User.where(id: self.active_lease_users(present_date, lessee: lessee, allow_future: allow_future, lease_user_where: lease_user_where).select(:user_id))
  end
  
  def current_lease_users(*linear, **keyword)
    active_lease_users(*linear, **keyword)
  end
  
  def current_users(*linear, **keyword)
    active_users(*linear, **keyword)
  end

  # Lease.activate
  def activate
    if status != 'current' && (start_date..end_date === Time.zone.now)
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
    end
  end

  # Lease.deactivate
  def deactivate
    return unless status == 'current'

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

  def update_status

    new_status =
      if (start_date..end_date) === Time.zone.now.to_date
        'current'
      elsif Time.zone.now.to_date < start_date
        'pending'
      elsif Time.zone.now.to_date > end_date
        'expired'
      end

    update(status: new_status) unless new_status.nil?
  end

  def update_unit_occupation
    insurable.update(occupied: insurable.leases.current.present?)
  end

  def update_users_status
    users.each do |user|
      user.update(has_current_leases: user.leases.current.exists?, has_leases: user.leases.exists?)
    end
  end

  def related_records_list
    %w[insurable account]
  end

  # Lease.primary_insurable

  def primary_user
    lease_users.where(primary: true).take&.user
  end
  
  def matching_policies(users: nil, policy_type_id: 1, policy_status: Policy.active_statuses, active_at: nil)
    # support all weird user types
    user_set ||= self.users
    user_set = [users] if users.class == ::User || users.class == ::Integer
    user_set = user_set.map{|u| u.class == ::Integer ? u : u.id }
    # do it bro
    to_return = self.insurable.policies
    unless active_at.nil?
      to_return = to_return.where(expiration_date: nil).or(to_return.where("expiration_date >= ?", active_at))
      to_return = to_return.where(cancellation_date:  nil).or(to_return.where("cancellation_date >= ?", active_at))
      to_return = to_return.where("effective_date <= ?", active_at)
    end
    to_return = to_return.where(policy_type_id: policy_type_id, status: policy_status, id: PolicyUser.where(user_id: user_set).select(:policy_id))
    return to_return
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
    errors.add(:end_date, 'must come after start date') if !end_date.nil? && start_date >= end_date
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
