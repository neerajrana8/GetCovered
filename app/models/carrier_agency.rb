##
# Carrier Agency Model
# file: +app/models/carrier_agency.rb+

class CarrierAgency < ApplicationRecord
  include RecordChange
  
  BLOCKED_POLICY_TYPES = [] # was 2,3 to prevent MP and MPC from being included... but I don't think we really want to do that...

  belongs_to :carrier
  belongs_to :agency

  has_many :carrier_agency_policy_types, dependent: :destroy
  has_many :commission_strategies,
    through: :carrier_agency_policy_types
  has_many :carrier_agency_authorizations, dependent: :destroy
  has_many :histories, as: :recordable
  def billing_strategies; ::BillingStrategy.where(carrier_id: self.carrier_id, agency_id: self.agency_id); end
  
  accepts_nested_attributes_for :carrier_agency_policy_types,
    reject_if: :should_reject_capt?,
    allow_destroy: true
  accepts_nested_attributes_for :carrier_agency_authorizations,
    allow_destroy: true

  before_destroy :remove_authorizations,
                 :disable_billing_strategies

  validate :carrier_agency_assignment_unique


  def agency_title
    agency.try(:title)
  end

  def disable
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
    
    def should_reject_capt?(attrs)
      return true if ::CarrierAgency::BLOCKED_POLICY_TYPES.include?(attrs['policy_type_id'])
      return true if self.carrier_agency_policy_types.any? do |capt|
        capt.id && capt.policy_type_id == attrs['policy_type_id'] && (attrs['commission_strategy_attributes'].blank? || attrs['commission_strategy_attributes'].all? do |csa|
          capt.send(csa.first) == csa.second
        end)
      end
      return false
    end
    
end
