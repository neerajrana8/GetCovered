# Master Policy Configuration model
# file: app/models/master_policy_configuration.rb
#

class MasterPolicyConfiguration < ApplicationRecord
  after_initialize :set_program_start_date, if: Proc.new { self.new_record? }

  belongs_to :carrier_policy_type
  belongs_to :configurable, polymorphic: true

  validate :uniqueness_of_assignment
  validates :placement_cost, numericality: { greater_than: 0 }
  validates :force_placement_cost, numericality: { greater_than: :placement_cost },
                                  unless: Proc.new { self.force_placement_cost.nil? }

  enum program_type: { auto: 0, choice: 1 }

  def charge_amount(force = false)
    return_charge = if force == false
                      self.placement_cost
                    else
                      self.force_placement_cost.nil? ? self.placement_cost : self.force_placement_cost
                    end
    return return_charge
  end

  private

  def set_program_start_date
    self.program_start_date ||= (Time.current + 1.month).at_beginning_of_month
  end

  def uniqueness_of_assignment
    if MasterPolicyConfiguration.exists?(carrier_policy_type: self.carrier_policy_type, configurable: self.configurable)
      errors.add(:base, message: "#{ self.configurable.title } already has a configuration for a Master Policy with #{ self.carrier_policy_type.carrier.title }")
    end
  end
end
