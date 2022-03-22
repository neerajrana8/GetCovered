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

  def term_amount(coverage = nil, t = DateTime.current)
    amount = nil
    coverage_check = coverage.nil? ? false : coverage.is_a?(Policy) && ::PolicyType::MASTER_COVERAGE_ID == coverage.policy_type_id
    if coverage_check
      first_month = t.month == coverage.effective_date.month &&
                    t.year == coverage.effective_date.year

      last_month = coverage.expiration_date.nil? ? false : t.month == coverage.expiration_date.month &&
                                                           t.year == coverage.expiration_date.year

      if prorate_charges == true && (first_month || last_month)
        days_in_month = t.end_of_month.day
        current_day = t.current.day
        total_monthly_charge = charge_amount(coverage.force_placed)
        daily_charge_amount = total_monthly_charge.to_f / days_in_month

        if first_month && last_month
          days = coverage.expiration_date.day - coverage.effective_date.day
        elsif first_month
          days = days_in_month - current_day
        elsif last_month
          days = coverage.expiration_date.day
        end

        amount = (daily_charge_amount * days).ceil(0)
      else
        amount = charge_amount(coverage.force_placed)
      end
    end
    return amount
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
