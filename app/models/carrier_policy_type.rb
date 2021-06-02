##
# =Carrier Policy Type Model
# file: +app/models/carrier_policy_type.rb+

class CarrierPolicyType < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :commission_strategy, optional: true # temporarily optional only

  has_many :carrier_policy_type_availabilities, dependent: :destroy

  accepts_nested_attributes_for :commission_strategy
  accepts_nested_attributes_for :carrier_policy_type_availabilities, allow_destroy: true
  
  before_validation :manipulate_dem_nested_boiz_like_a_boss # we don't restrict this to on: :create. that way it can be applied to commission_strategy updates too

  
  private
  
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

end
