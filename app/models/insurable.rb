class Insurable < ApplicationRecord
  # Concerns
  # include CarrierQbeCommunity, EarningsReport, RecordChange
  
  belongs_to :account
  belongs_to :insurable, optional: true
  belongs_to :insurable_type
  
  has_many :insurables
  has_many :carrier_insurable_profiles
	
	has_many :addresses,
       as: :addressable,
       autosave: true

  accepts_nested_attributes_for :addresses
  
  enum category: ['property', 'entity']
  
  def primary_address
		return addresses.where(primary: true).take 
	end
end
