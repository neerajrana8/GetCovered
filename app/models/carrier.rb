##
# Carrier Model
# file: +app/models/carrier.rb+

class Carrier < ApplicationRecord
  include SetSlug,
          SetCallSign,
          ElasticsearchSearchable
  
  after_initialize  :initialize_carrier
  
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
  
  validates_presence_of :slug, :call_sign
      
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
  end

  private
  
    def initialize_carrier
      self.syncable = false if self.syncable.nil?
      self.rateable = false if self.rateable.nil?
      self.quotable = false if self.quotable.nil?
      self.bindable = false if self.bindable.nil?
      self.verifiable = false if self.verifiable.nil?
      self.enabled = false if self.enabled.nil?
    end
end
