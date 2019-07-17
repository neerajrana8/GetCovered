class Insurable < ApplicationRecord
  # Concerns
  include CarrierQbeInsurable#, EarningsReport, RecordChange
  
  belongs_to :account
  belongs_to :insurable, optional: true
  belongs_to :insurable_type
  
  has_many :insurables
  has_many :carrier_insurable_profiles
	
	has_many :events,
	    as: :eventable
	    
  has_many :leases
	
	has_many :addresses,
       as: :addressable,
       autosave: true

  accepts_nested_attributes_for :addresses
  
  enum category: ['property', 'entity']
  
  scope :residential_communities, -> { joins(:insurable_type).where("insurable_types.title = 'Residential Community'")}
  scope :residential_units, -> { joins(:insurable_type).where("insurable_types.title = 'Residential Unit'")}
  
  # Insurable.primary_address
  #
  
  def primary_address
		return addresses.where(primary: true).take 
	end
	
	# Insurable.create_carrier_profile(carrier_id)
	#
	
	def create_carrier_profile(carrier_id)
  	carrier = Carrier.find(carrier_id)
    if !carrier.nil? && carrier.carrier_insurable_types
                               .exists?(insurable_type: insurable_type)
      carrier_insurable_type = carrier.carrier_insurable_types
                                      .where(insurable_type: insurable_type).take
      self.carrier_insurable_profiles.create!(traits: carrier_insurable_type.profile_traits, 
                                              data: carrier_insurable_type.profile_data,
                                              carrier: carrier)
    end  	
  end
  
  # Insurable.carrier_profile(carrier_id)
  #
  
  def carrier_profile(carrier_id)
    unless carrier_id.nil?
		  return carrier_insurable_profiles.where(carrier_id: carrier_id).take 
		end
	end

end
