##
# =Carrier Policy Type Model
# file: +app/models/carrier_policy_type.rb+

class CarrierPolicyType < ApplicationRecord
  attr_accessor :disable_tree_repair
  
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :commission_strategy

  has_many :fees, as: :assignable
  has_many :carrier_policy_type_availabilities, dependent: :destroy
  has_many :master_policy_configurations

  accepts_nested_attributes_for :commission_strategy
  accepts_nested_attributes_for :carrier_policy_type_availabilities, allow_destroy: true
  
  before_validation :manipulate_dem_nested_boiz_like_a_boss, # we don't restrict this to on: :create. that way it can be applied to commission_strategy updates too
    unless: Proc.new{|cpt| cpt.carrier.nil? || cpt.policy_type.nil? }

  after_update :repair_commission_strategy_tree,
    if: Proc.new{|cpt| !cpt.disable_tree_repair && cpt.saved_change_to_attribute?('commission_strategy_id') }
  
  validate :premium_proration_calculation_valid


  private
  
    def premium_proration_calculation_valid
      unless ::PolicyPremiumItem.proration_calculations.has_key?(self.premium_proration_calculation)
        errors.add(:premium_proration_calculation, "must be a valid proration calculation method")
      end
    end
  
    # fills out appropriate defaults for passed CommissionStrategy nested attributes or unsaved associated model
    def manipulate_dem_nested_boiz_like_a_boss
      if !self.commission_strategy.nil? && self.commission_strategy.id.nil?
        cs = self.commission_strategy
        big_old_papa_strat = nil
        magister = nil
        if cs.title.blank?
          magister ||= ::Agency.where(master_agency: true).take
          cs.title = "#{magister.title} / #{self.carrier.title} #{self.policy_type.title} Commission"
        end
        if cs.recipient_id.nil? && cs.recipient_type.nil?
          magister ||= ::Agency.where(master_agency: true).take
          cs.recipient = magister
        end
        if cs.commission_strategy_id.nil?
          big_old_papa_strat ||= self.carrier.get_or_create_universal_parent_commission_strategy
          cs.commission_strategy = big_old_papa_strat
        end
      end
    end
    
    def repair_commission_strategy_tree
      # we update the master agency CAPT to have the same CS, relying on CAPT#repair_commission_strategy_tree to fix the rest
      capt = ::CarrierAgencyPolicyType.references(carrier_agencies: :agencies).includes(carrier_agency: :agency)
                    .where(
                      policy_type_id: self.policy_type_id,
                      carrier_agencies: { carrier_id: self.carrier_id, agencies: { master_agency: true } }
                    ).take
      unless capt.nil?
        begin
          capt.update!(commission_strategy_id: self.commission_strategy_id)
        rescue ActiveRecord::RecordInvalid => err
          self.errors.add(:carrier_agency_policy_type, "for master agency (id #{capt.id}) failed to update: #{err.record.errors.to_h}")
          raise ActiveRecord::RecordInvalid, self
        end
      end
    end

end
