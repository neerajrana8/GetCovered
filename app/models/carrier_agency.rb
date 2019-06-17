##
# Carrier Agency Model
# file: +app/models/carrier_agency.rb+

class CarrierAgency < ApplicationRecord
  belongs_to :carrier
  belongs_to :agency
  
  validate :carrier_agency_assignment_unique
  
  private
  
    def carrier_agency_assignment_unique
      if CarrierAgency.where(carrier: carrier, agency: agency).count > 1
        errors.add(:agency, "assignment to #{ carrier.title } already exists") 
      end
    end
end
