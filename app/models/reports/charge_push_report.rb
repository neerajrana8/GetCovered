# == Schema Information
#
# Table name: reports
#
#  id               :bigint           not null, primary key
#  duration         :integer
#  range_start      :datetime
#  range_end        :datetime
#  data             :jsonb
#  reportable_type  :string
#  reportable_id    :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  type             :string
#  reportable2_id   :bigint
#  reportable2_type :string
#
module Reports
  # NOTE: this reports shows charge amounts for corresponding child policy by account ID and date (month and year);
  #       reportable is account and reportable2 is community
  class ChargePushReport < ::Report
    NAME = 'Charge Push Report'.freeze

    after_initialize :validate_dates

    def generate
      # NOTE: can't filter by community in #policies cause of chosen arch, so do it here
      data['rows'] = policies.filter_map do |policy|
        row = build_row(policy)
        row if row['community_id'] == reportable2_id || reportable2_id.nil?
      end

      self
    end

    def column_names
      {
        'user_name' => 'User Name',
        'user_email' => 'User Email',
        'community_name' => 'Community Name',
        'building_address' => 'Building Address',
        'unit_number' => 'Unit Number',
        'lease_start_date' => 'Lease Start Date',
        'user_id' => 'User ID',
        'lease_id' => 'Lease ID',
        'unit_id' => 'Unit ID',
        'community_id' => 'Community ID',
        'charge' => 'Charge'
      }
    end

    def headers
      column_names.keys
    end

    private

    def set_defaults
      self.data ||= {
        'rows' => []
      }
    end

    def validate_dates
      return if range_start.utc.month == range_end.utc.month && range_start.utc.year == range_end.utc.year

      raise 'Range dates should be in the same month'
    end

    def policies
      query = Policy
        .includes(:policy, :insurables, :users, :agency, :account, policy: :insurables)
        .master_policy_coverages
        .where(range_sql_condition, range_start: range_start.utc, range_end: range_end.utc)

      query = query.where(account: reportable) if reportable

      query
    end

    def range_sql_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end)
        OR (expiration_date > :range_start AND expiration_date < :range_end)
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def build_row(policy)
      unit = policy.primary_insurable
      parent_community = unit&.parent_community
      lease = unit.leases.where(status: 'current').take
      insured = lease&.primary_user
      master_policy = policy.policy
      mpc = policy.master_policy_configuration

      {
        'user_name' => insured&.full_name,
        'user_email' => insured&.email,
        'community_name' => parent_community&.title,
        'building_address' => unit&.parent_building&.id,
        'unit_number' => unit&.title,
        'lease_start_date' => lease&.start_date,
        'user_id' => insured&.id,
        'lease_id' => lease&.id,
        'unit_id' => unit&.id,
        'community_id' => parent_community&.id,
        'charge' => format_monetary_field(calculate_charge_amount(policy, mpc))
      }
    end

    def calculate_charge_amount(coverage, mpc)
      return unless coverage && mpc

      date = DateTime.new(year, month, 1)

      # NOTE: return 0 if target month is not covered at all
      return 0 unless (date..date.end_of_month).to_a & (coverage.effective_date..coverage.expiration_date).to_a

      if month == coverage.effective_date.month && year == coverage.effective_date.year # target month is coverage start month
        mpc.term_amount(coverage, coverage.effective_date.end_of_month)
      elsif month == coverage.expiration_date.month && year == coverage.expiration_date.year # target month is coverage end month
        mpc.term_amount(coverage, coverage.expiration_date.end_of_month)
      else
        mpc.term_amount(coverage, date)
      end
    end

    def format_monetary_field(value)
      "$#{format('%.2f', value.to_i / 100.0)}"
    end

    def month
      range_start.utc.month || range_end.utc.month
    end

    def year
      range_start.utc.year || range_end.utc.year
    end
  end
end
