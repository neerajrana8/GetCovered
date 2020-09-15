##
# Carrier Agency Authorization Model
# file: +app/models/carrier_agency_authorization.rb+

class CarrierAgencyAuthorization < ApplicationRecord
  include Blacklistable
  
  belongs_to :carrier_agency
  belongs_to :policy_type
  belongs_to :agency

  has_one :carrier, through: :carrier_agency

  has_many :fees, as: :assignable
  
  enum state: { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6, 
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13, 
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20, 
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27, 
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34, 
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41, 
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48, 
                WV: 49, WY: 50 }
  
  validates_presence_of :state
  validates_uniqueness_of :state, scope: 'carrier_agency_id', message: 'record for parent Carrier Policy Type already exists'
  validate :agency_matches_carrier_agency, unless: proc { |caa| caa.agency_id.nil? || caa.carrier_agency.nil? }
  
  private
  
  def agency_matches_carrier_agency
    errors.add(:carrier_agency, 'must be a valid carrier_agency for the selected agency') unless carrier_agency.agency_id == agency_id
  end
end
