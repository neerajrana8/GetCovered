##
# CarrierAgencyPolicyType Model
# file: +app/models/carrier_agency_policy_type.rb+

class CarrierAgencyPolicyType < ApplicationRecord
  attr_accessor :callbacks_disabled

  belongs_to :carrier_agency
  belongs_to :policy_type
  belongs_to :commission_strategy
    
  has_one :carrier,
    through: :carrier_agency
  has_one :agency,
    through: :carrier_agency
  
  accepts_nested_attributes_for :commission_strategy
  
  def carrier_policy_type; ::CarrierPolicyType.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_agency.carrier_id).take; end
  def carrier_agency_authorizations; ::CarrierAgencyAuthorization.where(policy_type_id: self.policy_type_id, carrier_agency_id: self.carrier_agency_id); end
  def billing_strategies; ::BillingStrategy.where(policy_type_id: self.policy_type_id, carrier_id: self.carrier_agency.carrier_id, agency_id: self.carrier_agency.agency_id); end
  def agency_id; self.carrier_agency.agency_id; end
  def carrier_id; self.carrier_agency.carrier_id; end
  
  before_validation :manipulate_dem_nested_boiz_like_a_boss,
    on: :create, # this cannot be a before_create, or the CS will already have been saved
    unless: Proc.new{|capt| capt.callbacks_disabled }
  after_create :create_authorizations,
    unless: Proc.new{|capt| capt.callbacks_disabled }
  after_create :set_billing_strategies,
    unless: Proc.new{|capt| capt.callbacks_disabled }
  before_destroy :remove_authorizations,
                 :disable_billing_strategies
  
  private
  
    def create_authorizations
      # Prevent Alaska & Hawaii as being set as available; prevent already-created CAAs from being recreated
      blocked_states = [0, 11]
      skipped_states = ::CarrierAgencyAuthorization.where(carrier_agency_id: self.carrier_agency_id, policy_type_id: self.policy_type_id).map{|caa| caa.read_attribute_before_type_cast(:state) }
      51.times do |state|
        next if skipped_states.include?(state)
        ::CarrierAgencyAuthorization.create!(
          carrier_agency_id: self.carrier_agency_id,
          policy_type_id: self.policy_type_id,
          state: state,
          available: blocked_states.include?(state) ? false : true
        )
      end
    end

    def set_billing_strategies
      # Create billing strategies as dups of GC's billing strategies, unless we already have some
      return if self.agency.master_agency
      strats = ::BillingStrategy.where(agency_id: [self.agency_id, ::Agency.where(master_agency: true).take.id], carrier_id: self.carrier_id, policy_type: self.policy_type_id)
      unless strats.any?{|bs| bs.agency_id == self.agency_id }
        strats.each do |bs|
          new_bs = bs.dup
          new_bs.agency_id = self.agency_id
          new_bs.save!
        end
      end
    end

    def remove_authorizations
      self.carrier_agency_authorizations.destroy_all
    end

    def disable_authorizations
      self.carrier_agency_authorizations.each{|caa| caa.update available: false } # this isn't actually used right now...
    end

    def disable_billing_strategies
      self.billing_strategies.update_all(enabled: false)
    end
    
    # fills out appropriate defaults for passed CommissionStrategy nested attributes or unsaved associated model;
    # if no commission strategy is passed and our parent CommissionStrategy (i.e. our parent agency's corresponding CAPT's commission strategy, or if no parent agency, our corresponding CarrierPolicyType's commission strategy)
    # has recipient == self.agency, we go ahead and create a child CommissionStrategy with the same data but a more descriptive title (assuming no one creates CAPTs whose CS recipient is not the CAPT's agency, this
    # can only happen when self.agency == GetCovered, since the parent CS will belong to a CarrierPolicyType and they always have recipient GetCovered)
    def manipulate_dem_nested_boiz_like_a_boss
      if self.commission_strategy.nil?
        meesa_own_daddy = self.carrier_agency.agency.agency_id.nil? ?
          self.carrier_policy_type.commission_strategy
          : ::CarrierAgencyPolicyType.where(carrier_id: self.carrier_id, agency_id: self.carrier_agency.agency.agency_id, policy_type_id: self.policy_type_id).take.commission_strategy
        if meesa_own_daddy.recipient == self.carrier_agency.agency
          self.commission_strategy = ::CommissionStrategy.new(
            title: "#{self.carrier_agency.agency.title} / #{self.carrier_agency.carrier.title} #{self.policy_type.title} Commission",
            percentage: meesa_own_daddy.percentage,
            recipient: self.carrier_agency.agency,
            commission_strategy: meesa_own_daddy
          )
        end
      elsif self.commission_strategy.id.nil?
        cs = self.commission_strategy
        cs.title = "#{self.carrier_agency.agency.title} / #{self.carrier_agency.carrier.title} #{self.policy_type.title} Commission" if cs.title.blank?
        cs.recipient = self.carrier_agency.agency if cs.recipient_id.nil? && cs.recipient_type.nil?
        if cs.commission_strategy_id.nil?
          meesa_own_daddy = self.carrier_agency.agency.agency_id.nil? ?
            self.carrier_policy_type.commission_strategy
            : ::CarrierAgencyPolicyType.where(carrier_id: self.carrier_id, agency_id: self.carrier_agency.agency.agency_id, policy_type_id: self.policy_type_id).take.commission_strategy
          cs.commission_strategy = meesa_own_daddy 
        end
      end
    end
end
