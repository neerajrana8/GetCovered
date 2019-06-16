##
# Carrier Model
# file: +app/models/carrier.rb+

class Carrier < ApplicationRecord
  include SetSlug,
  				SetCallSign
  
  after_initialize  :initialize_carrier
  
  # Relationships
  has_many :carrier_policy_types
  has_many :policy_types, 
    through: :carrier_policy_types
  has_many :carrier_policy_type_availabilities, 
    through: :carrier_policy_types
  
  # Validations
  validates :title, presence: true,
                    uniqueness: true  
      
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
