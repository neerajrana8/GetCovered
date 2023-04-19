# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  range_start     :datetime
#  range_end       :datetime
#  data            :jsonb
#  reportable_type :string
#  reportable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string
#
module Reports
  # NOTE: this reports shows charge amounts calculated in master policy configurations for corresponding coverages
  class CoverageChargesReport < ::Report
    NAME = 'Coverage Charges Report'.freeze

    def generate
      data['rows'] = coverages.map { |coverage| build_row(coverage) }
      self
    end

    def column_names
      {
        'insurable_address' => 'Insurable Address',
        'user_full_name' => 'User',
        'charge_amount' => 'Charge Amount',
        'master_policy_configuration_id' => 'Master Policy Configuration ID',
        'master_policy_id' => 'Master Policy ID',
        'policy_id' => 'Policy ID',
        'insurable_id' => 'Insurable ID',
        'user_id' => 'User ID'
      }
    end

    def headers
      %w[
        insurable_address user_full_name charge_amount master_policy_configuration_id
        master_policy_id policy_id insurable_id user_id
      ]
    end

    private

    def set_defaults
      self.data ||= {
        'rows' => []
      }
    end

    def coverages
      Policy
        .includes(:policy, :insurables, :users, :agency, :account, policy: :insurables)
        .master_policy_coverages
        .where(range_sql_condition, range_start: range_start, range_end: range_end)
    end

    def range_sql_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end)
        OR (expiration_date > :range_start AND expiration_date < :range_end)
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def build_row(coverage)
      insurable = coverage.primary_insurable
      insured = insurable.leases.where(status: 'current').take&.primary_user
      master_policy = coverage.policy
      mpc = fetch_master_policy_configuration(coverage, master_policy, insurable)

      {
        'insurable_address' => insurable&.primary_address&.full_street_address,
        'user_full_name' => insured&.full_name,
        'charge_amount' => mpc&.charge_amount ? format('%.2f', mpc&.charge_amount / 100.0) : nil,
        'master_policy_configuration_id' => mpc&.id,
        'master_policy_id' => master_policy&.id,
        'policy_id' => coverage&.id,
        'insurable_id' => insurable&.id,
        'user_id' => insured&.id
      }
    end

    def fetch_master_policy_configuration(coverage, master_policy, insurable)
      return coverage.master_policy_configuration if coverage.master_policy_configuration

      lease = coverage.latest_lease(lease_status: ['pending', 'current'])
      available_lease_date = lease.nil? ? DateTime.current.to_date : lease.sign_date.nil? ? lease.start_date : lease.sign_date

      begin
        MasterPolicy::ConfigurationFinder.call(master_policy, insurable, available_lease_date)
      rescue
        nil
      end
    end
  end
end
