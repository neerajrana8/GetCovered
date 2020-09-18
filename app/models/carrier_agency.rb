##
# Carrier Agency Model
# file: +app/models/carrier_agency.rb+

class CarrierAgency < ApplicationRecord
  include RecordChange

  belongs_to :carrier
  belongs_to :agency
  
  has_many :carrier_agency_authorizations, dependent: :destroy
  
  validate :carrier_agency_assignment_unique

  accepts_nested_attributes_for :carrier_agency_authorizations, update_only: true, allow_destroy: true
  
  private
  
  def carrier_agency_assignment_unique
    if CarrierAgency.where(carrier: carrier, agency: agency).count > 1
      errors.add(:agency, "assignment to #{carrier.title} already exists") 
    end
  end
end
