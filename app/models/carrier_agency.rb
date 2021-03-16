##
# Carrier Agency Model
# file: +app/models/carrier_agency.rb+

class CarrierAgency < ApplicationRecord
  include RecordChange

  after_create :create_authorizations,
               :set_billing_strategies
  before_destroy :remove_authorizations,
                 :disable_billing_strategies

  belongs_to :carrier
  belongs_to :agency
  
  has_many :carrier_agency_authorizations, dependent: :destroy
  has_many :histories, as: :recordable

  validate :carrier_agency_assignment_unique

  accepts_nested_attributes_for :carrier_agency_authorizations, allow_destroy: true

  def agency_title
    agency.try(:title)
  end
  
  def billing_strategies
    BillingStrategy.where(agency: agency, carrier: carrier)
  end

  def dsiable
    disable_authorizations()
    disable_billing_strategies()
  end
  
  private

  def blocked_policy_types
    # Prevent Master Policy & Master Policy Coverages from being included
    return [2,3]
  end
  
  def create_authorizations
    # Prevent Alaska & Hawaii as being set as available
    blocked_states = [0,11]
    
    carrier.carrier_policy_types.each do |cpt|
      unless blocked_policy_types().include?(cpt.policy_type_id)
        51.times do |state|
          self.carrier_agency_authorizations.create(
            state: state,
            available: blocked_states.include?(state) ? false : true,
            policy_type: cpt.policy_type
          )
        end
      end
    end
  end

  def set_billing_strategies
    carrier.carrier_policy_types.each do |cpt|
      strats = BillingStrategy.where(agency_id: 1, carrier: carrier, policy_type: cpt.policy_type)
      unless blocked_policy_types().include?(cpt.policy_type_id) || strats.nil?
        strats.each do |bs|
          new_bs = bs.dup
          new_bs.agency = agency
          new_bs.save
        end
      end
    end
  end

  def remove_authorizations
    self.carrier_agency_authorizations.destroy_all
  end

  def disable_authorizations
    carrier_agency_authorizations.each { |caa| caa.update available: false }
  end

  def disable_billing_strategies
    strats = BillingStrategy.where(agency: agency, carrier: carrier)
    unless strats.nil?
      strats.each { |bs| bs.update enabled: false }
    end
  end

  def carrier_agency_assignment_unique
    if CarrierAgency.where(carrier: carrier, agency: agency).count > 1
      errors.add(:agency, "assignment to #{carrier.title} already exists") 
    end
  end
end
