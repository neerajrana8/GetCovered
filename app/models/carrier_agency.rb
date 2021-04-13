##
# Carrier Agency Model
# file: +app/models/carrier_agency.rb+

class CarrierAgency < ApplicationRecord
  include RecordChange
  
  BLOCKED_POLICY_TYPES = [2, 3] # Prevent Master Policy & Master Policy Coverages from being included

  belongs_to :carrier
  belongs_to :agency

  has_many :carrier_agency_policy_types, dependent: :destroy
  has_many :commission_strategies,
    through: :carrier_agency_policy_types
  has_many :carrier_agency_authorizations, dependent: :destroy
  has_many :histories, as: :recordable
  def billing_strategies; ::BillingStrategy.where(carrier_id: self.carrier_id, agency_id: self.agency_id); end
  
  accepts_nested_attributes_for :carrier_agency_policy_types,
    reject_if: Proc.new{|attrs| ::CarrierAgency::BLOCKED_POLICY_TYPES.include?(attrs['policy_type_id'] || attrs[:policy_type_id]) }
  accepts_nested_attributes_for :carrier_agency_authorizations,
    allow_destroy: true


  before_validation :manipulate_dem_nested_boiz_like_a_boss,
    on: :create # This cannot be a before_create, or the CAPTs will already have been saved. If there are any issues after a rails upgrade or something, see note in method body.
  before_destroy :remove_authorizations,
                 :disable_billing_strategies

  validate :carrier_agency_assignment_unique


  def agency_title
    agency.try(:title)
  end

  def disable
    # Moose warning to force a new deployment
    disable_authorizations
    disable_billing_strategies
  end
  
  private

    def remove_authorizations
      self.carrier_agency_authorizations.destroy_all
    end
    
    def disable_authorizations
      carrier_agency_authorizations.each{|caa| caa.update available: false }
    end

    def disable_billing_strategies
      billing_strategies.update_all(enabled: false)
    end

    def carrier_agency_assignment_unique
      if CarrierAgency.where(carrier: carrier, agency: agency).count > 1
        errors.add(:agency, "assignment to #{carrier.title} already exists")
      end
    end
    
    def manipulate_dem_nested_boiz_like_a_boss
      (self.carrier_agency_policy_types || []).select{|capt| capt.id.nil? }.each do |capt|
        #capt.carrier_agency = self # this isn't needed anymore eh
        
        # WARNING: this will run before nested attribute validations according to tests. but if everything suddenly breaks hideously on a rails upgrade or something,
        # try putting the before_validation line before the association lines, or make sure to manually re-invoke the CAPT manipulate_dem_nested_boiz_like_a_boss methods here after setting carrier & agency
        # (because the CAPTs use this same structure to set up their CommissionStrategies from partial attributes, and if they don't have an agency yet shizzle will go bizzle real fizzle)
      end
    end
    
end
