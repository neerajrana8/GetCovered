##
# Carrier Model
# file: +app/models/carrier.rb+

class Carrier < ApplicationRecord
  include ElasticsearchSearchable
  include SetCallSign
  include SetSlug
  include RecordChange
  
  after_initialize :initialize_carrier
  
  # Relationships
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
  
  has_many :commission_strategies
    
  has_many :fees,
           as: :ownerable
    
  has_many :carrier_insurable_types
  has_many :carrier_insurable_profiles
  has_many :carrier_class_codes
  
  has_many :policy_application_fields

  has_many :access_tokens,
           as: :bearer  

  # Validations
  validates :title, presence: true,
                    uniqueness: true
  
  validates :integration_designation, inclusion: { in: %w[qbe qbe_specialty crum pensio msi], message: 'must be valid' }
  
  validates_presence_of :slug, :call_sign

  accepts_nested_attributes_for :carrier_policy_types, allow_destroy: true

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
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
