##
# Carrier Model
# file: +app/models/carrier.rb+

class Carrier < ApplicationRecord
  include ElasticsearchSearchable
  include SetCallSign
  include SetSlug
  include RecordChange
  
  # Relationships
  belongs_to :commission_strategy, # the universal parent commission strategy
    optional: true
  
  has_many :carrier_policy_types
  has_many :policy_types, 
           through: :carrier_policy_types
  has_many :carrier_policy_type_availabilities, 
           through: :carrier_policy_types
  
  has_many :carrier_agencies
  has_many :agencies,
           through: :carrier_agencies
  has_many :carrier_agency_authorizations,
           through: :carrier_agencies
  
  has_many :commission_strategies, as: :recipient
  has_many :commissions, as: :recipient
  has_many :commission_items, through: :commissions
    
  has_many :fees,
           as: :ownerable
    
  has_many :carrier_insurable_types
  has_many :carrier_insurable_profiles
  has_many :carrier_class_codes
  has_many :histories, as: :recordable
  has_many :policy_application_fields

  has_many :access_tokens,
           as: :bearer
           
  # Callbacks
  after_initialize :initialize_carrier

  # Validations
  validates :title, presence: true,
                    uniqueness: true
  
  validates :integration_designation, inclusion: { in: %w[qbe qbe_specialty crum pensio msi dc], message: 'must be valid' }
  
  validates_presence_of :slug, :call_sign

  accepts_nested_attributes_for :carrier_policy_types, allow_destroy: true

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
  end
  
  def uses_stripe?
    return(![5,6].include?(self.id))
  end

  def get_or_create_universal_parent_commission_strategy
    return self.commission_strategy || ::CommissionStrategy.create!( 
      title: "#{self.title} Commission",
      percentage: 100,
      recipient: self,
      commission_strategy: nil
    )
  end

  private
  
  def initialize_carrier
    self.syncable = false if syncable.nil?
    self.rateable = false if rateable.nil?
    self.quotable = false if quotable.nil?
    self.bindable = false if bindable.nil?
    self.verifiable = false if verifiable.nil?
    self.enabled = false if enabled.nil?
  end
end
