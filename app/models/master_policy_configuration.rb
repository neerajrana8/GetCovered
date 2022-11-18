# == Schema Information
#
# Table name: master_policy_configurations
#
#  id                         :bigint           not null, primary key
#  program_type               :integer          default("auto")
#  grace_period               :integer          default(0)
#  integration_charge_code    :string
#  prorate_charges            :boolean          default(FALSE)
#  auto_post_charges          :boolean          default(TRUE)
#  consolidate_billing        :boolean          default(TRUE)
#  program_start_date         :datetime
#  program_delay              :integer          default(0)
#  placement_cost             :integer          default(0)
#  force_placement_cost       :integer
#  carrier_policy_type_id     :bigint           not null
#  configurable_type          :string           not null
#  configurable_id            :bigint           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  enabled                    :boolean          default(FALSE)
#  integration_account_number :string
#  lease_violation_only       :boolean          default(TRUE)
#
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
    return force ? self.force_placement_cost.nil? ? self.placement_cost : self.force_placement_cost : self.placement_cost
  end

  def admin_fee_amount(force = false)
    return force ? self.force_admin_fee.nil? ? self.admin_fee : self.force_admin_fee : admin_fee
  end

  def daily_amount(amount: 0, day_count: 0)
    return amount.to_f / day_count
  end

  def term_amount(coverage = nil, t = DateTime.current)
    amount = nil
    coverage_check = coverage.nil? ? false : coverage.is_a?(Policy) && ::PolicyType::MASTER_COVERAGE_ID == coverage.policy_type_id
    if coverage_check
      amount = 0
      output = Array.new

      first_month = t.month == coverage.effective_date.month && t.year == coverage.effective_date.year
      last_month = coverage.expiration_date.nil? ? false : t.month == coverage.expiration_date.month &&
                                                           t.year == coverage.expiration_date.year

      total_monthly_charge = charge_amount(coverage.force_placed)
      total_admin_charge = admin_fee_amount(coverage.force_placed)

      output << "Total Charge Amount: #{ total_monthly_charge }"
      output << "Total Admin Fee: #{ total_admin_charge }"

      if (prorate_charges == true || prorate_admin_fee == true) && (first_month || last_month)
        current_day = coverage.effective_date.day - 1
        days_in_month = t.end_of_month.day
        daily_charge_amount = daily_amount(amount: total_monthly_charge, day_count: days_in_month)
        daily_admin_amount = daily_amount(amount: total_admin_charge, day_count: days_in_month)

        if first_month && last_month
          days = coverage.expiration_date.day - current_day
        elsif first_month
          days = days_in_month - current_day
        elsif last_month
          days = coverage.expiration_date.day
        end

        output << "Days in month: #{ days_in_month }"
        output << "Days: #{ days }"
        output << "Daily Charge Amount: #{ daily_charge_amount }"
        output << "Daily Admin Fee: #{ daily_admin_amount }"
        output << "Prorate Charge: #{ prorate_charges }"
        output << "Prorated Charge: #{ (daily_charge_amount * days).ceil(0) }"
        output << "Prorate Admin Fee: #{ prorate_admin_fee }"
        output << "Prorated Admin Fee: #{ (daily_admin_amount * days).ceil(0) }"

        amount += (daily_charge_amount * days).ceil(0) if prorate_charges == true
        amount += (daily_admin_amount * days).ceil(0) if prorate_admin_fee == true

        output << "Response Amount Output 1: #{ amount }"
      end

      amount += total_monthly_charge if prorate_charges == false
      amount += total_admin_charge if prorate_admin_fee == false

      output << "Response Amount Output 1: #{ amount }"

    end

    puts output
    return amount
  end

  def find_closest_account
    if self.configurable_type == "Account"
      return self.configurable
    elsif self.configurable_type == "Policy" ||
          self.configurable_type == "Insurable"
      return self.configurable&.account
    else
      return nil
    end
  end

  private

  def set_program_start_date
    self.program_start_date ||= (Time.current + 1.month).at_beginning_of_month
  end

  def uniqueness_of_assignment
    if MasterPolicyConfiguration.exists?(carrier_policy_type: self.carrier_policy_type, configurable: self.configurable)
      errors.add(:base, message: "#{ self.configurable.class.name } already has a configuration for a Master Policy with #{ self.carrier_policy_type.carrier.title }")
    end
  end
end
