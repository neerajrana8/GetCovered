# Lease model
# file: app/models/lease.rb

class Lease < ApplicationRecord
  # Concerns
  include RecordChange, ElasticsearchSearchable

  # Active Record Callbacks
  after_initialize :initialize_lease

  before_validation :set_type,
    unless: Proc.new { |lease| lease.unit.nil? }
  
  before_validation :set_reference,
  	if: Proc.new { |lease| lease.reference.nil? }

  after_commit :update_unit_occupation

  # Relationships
  # belongs_to :unit,
  #  required: true
    
  has_one :building,
    through: :unit
    
  has_one :community,
    through: :building

  belongs_to :account, 
    required: true

  has_one :policy,
    through: :unit

  has_one :master_policy_coverage,
    through: :unit

  has_many :lease_users

  has_many :users, 
    through: :lease_users

  has_many :histories,
    as: :recordable

  # Validations
  validates_presence_of :start_date, :end_date

  validate :start_date_precedes_end_date,
    unless: Proc.new { |lease| lease.end_date.nil? || lease.start_date.nil? }

  validates :type, presence: true,
    format: { with: /Residential|Commercial/, message: "must be Residential or Commercial" }

  validate :lease_type_matches_unit_type_if_present,
    unless: Proc.new { |lease| lease.unit.nil? }

  validate :policy_account_matches_lease_account,
    unless: Proc.new { |lease| lease.policy.nil? || lease.policy.account.nil? || account.nil? }

  validate :unit_account_matches_lease_account,
    unless: Proc.new { |lease| lease.unit.nil? || account.nil? }

  # Allow use of .type without invoking STI
  self.inheritance_column = nil

  enum status: [ :pending, :approved, :current, :expired, :rejected ]

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, analyzer: 'english'
      indexes :type, analyzer: 'english'
      indexes :status
      indexes :covered
      indexes :unit_id
      indexes :account_id
      indexes :start_date, type: 'date'
      indexes :end_date, type: 'date'
    end
  end

  # Lease.active?
  def active?
    range = start_date..end_date
    return range === Time.current
  end
  
  # Lease.activate
  def activate
    if status == 'approved'
      update status: 'current'
      update covered: true if unit.covered
            
      related_history = {
        data: { 
          leases: {  
            model: "Lease", 
            id: id, 
            message: "Lease ##{id} activated" 
          }
        }, 
        action: 'update_related'
      }
      
      self.related_records_list.each do |related|
        self.send(related).histories.create(related_history) unless self.send(related).nil?  
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
            model: "Lease", 
            id: id, 
            message: "Lease ##{id} deactivated" 
          }
        }, 
        action: 'update_related'
      }
      
      self.related_records_list.each do |related|
        self.send(related).histories.create(related_history) unless self.send(related).nil?  
      end

    end
  end

  def update_unit_occupation
    self.unit.update_occupation
  end
    
  def related_records_list
    return ['community', 'building', 'unit', 'account']  
  end

  private

    ## Initialize Lease
    def initialize_lease
      self.type = self.unit.type unless self.unit.nil?
    end

    def set_type
      self.type ||= unit.type
    end

    def start_date_precedes_end_date
      if start_date >= end_date
        errors.add(:end_date, "must come after start date")
      end
    end

    def lease_type_matches_unit_type_if_present
      if type != unit.type
        errors.add(:type, "must match the type of the leased property")
      end
    end

    def policy_account_matches_lease_account
      if policy.account.id != account.id
        errors.add(:policy, "must have same account as lease")
      end
    end

    def unit_account_matches_lease_account
      if unit.parent_account.id != account.id
        errors.add(:unit, "must have same account as lease")
      end
    end

    # History methods

    def related_classes_through
      [ :account, :building, :community, :unit ]
    end

    def related_create_hash(relation, related_model)
      {
        self.class.name.to_s.downcase.pluralize => {
          "model" => self.class.name.to_s,
          "id" => self.id,
          "message" => "New lease application"
        }
      }
    end
    
    def set_reference
	    return_status = false
	    
	    if reference.nil?
	      
	      loop do
	        self.reference = "#{account.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true
	        
	        break unless Lease.exists?(:reference => self.reference)
	      end
	    end
	    
	    return return_status	  	  
	  end
end

