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
  
  # Insurable.primary_address
  #
  
  def primary_address
		return addresses.where(primary: true).take 
	end
	
	# Insurable.create_profile_for_carrier(carrier_id)
	#
	
	def create_profile_for_carrier(carrier_id)
  	carrier = Carrier.find(carrier_id)
    if carrier.carrier_insurable_types
              .exists?(insurable_type == insurable_type)
      carrier_insurable_type = carrier.carrier_insurable_types
                                      .where(insurable_type_id: self.insurable_type_id).take
      self.carrier_insurable_profiles.create!(traits: carrier_insurable_type.profile_traits, 
                                              data: carrier_insurable_type.profile_data,
                                              carrier: carrier)
    end  	
  end

end
