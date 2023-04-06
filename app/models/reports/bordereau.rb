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
  class Bordereau < ::Report
    NAME = 'Bordereau'.freeze

    def generate
      data['rows'] = rows
      self
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << headers.map { |header| column_names[header] }
        data['rows'].each do |row|
          csv << headers.map { |attr| row[column_names[attr]] }
        end
      end
    end

    def column_names
      {
        'policy_number' => 'Policy Number',
        'insured_name' => 'Insured Name',
        'property_id' => 'Property ID',
        'property_name' => 'Property Name',
        'resident_name' => 'Resident Name',
        'resident_name2' => 'Resident Name 2',
        'resident_name3' => 'Resident Name 3',
        'resident_name4' => 'Resident Name 4',
        'street_address' => 'Street Address',
        'city' => 'City',
        'state' => 'State',
        'zip_code' => 'Zip Code',
        'unit_number' => 'Unit Number',
        'start_date' => 'Start Date',
        'end_date' => 'End Date',
        'policy_status' => 'Policy Status',
        'contents_coverage' => 'Contents Coverage',
        'master_liability' => 'Master Liability',
        'master_aggregate' => 'Master Agrregate',
        'premises_liability_coverage_limit' => "Tenant's Premises Liability Coverage Limit",
        'contents_amount' => 'Contents Amount',
        'animal_liability' => 'Animal Liability',
        'number_of_days' => 'Number of Days',
        'premium_with_taxes_per_day' => 'Premium with Taxes per Day',
        'premium_with_taxes' => 'Premium with Taxes'
      }
    end

    def headers
      %w[
        policy_number insured_name property_id property_name resident_name resident_name2 resident_name3 resident_name4
        street_address city state zip_code unit_number start_date end_date policy_status contents_coverage master_liability
        master_aggregate premises_liability_coverage_limit contents_amount animal_liability number_of_days
        premium_with_taxes_per_day premium_with_taxes
      ]
    end

    private

    def set_defaults
      self.data ||= {
        'rows' => []
      }
    end

    def rows
      coverages.map { |coverage| row(coverage) }
    end

    def coverages
      base_query =
        Policy.
          includes(:policy, :insurables, :users, :agency, :account, policy: :insurables).
          where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS).
          where(coverages_condition, range_start: range_start, range_end: range_end)
      coverages =
        if reportable.blank?
          base_query
        elsif reportable.is_a? Account
          base_query.where(account: reportable)
        elsif reportable.is_a? Agency
          base_query.where(agency: reportable)
        end
      coverages
    end

    def coverages_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end) 
        OR (expiration_date > :range_start AND expiration_date < :range_end) 
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def row(coverage)
      master_policy = coverage.policy
      primary_insurable = coverage.primary_insurable
      tenant = primary_insurable.leases.where(status: 'current').take&.primary_user
      insurable_address = primary_insurable&.primary_address

      {
        "Policy Number" => coverage.number,
        "Insured Name" => coverage.account&.title, # NOTE: see GCVR2-808 - Insured Name is the name group/entity holding the policy itself (ex. Essex Management Corporation)
        "Property ID" => property_id(primary_insurable),
        "Property Name" => property_name(primary_insurable),
        "Resident Name" => tenant&.profile&.first_name,
        "Resident Name 2" => tenant&.profile&.middle_name,
        "Resident Name 3" => tenant&.profile&.last_name,
        "Resident Name 4" => tenant&.profile&.suffix,
        "Street Address" => insurable_address&.street_name,
        "City" => insurable_address&.city,
        "State" => insurable_address&.state,
        "Zip Code" => insurable_address&.zip_code,
        "Unit Number" => primary_insurable&.title,
        "Start Date" => coverage.effective_date,
        "End Date" => end_date(coverage),
        "Policy Status" => coverage.status,
        "Contents Coverage" => contents_coverage(master_policy) ? 'Yes' : 'No',
        "Master Liability" => format_monetary_field(master_liability(master_policy)),
        "Master Aggregate" => format_monetary_field(master_aggregate(master_policy)),
        "Tenant's Premises Liability Coverage Limit" => format_monetary_field(premises_liability_coverage_limit(master_policy)),
        "Contents Amount" => format_monetary_field(contents_amount(master_policy)),
        "Animal Liability" => nil, # NOTE: We do not currently have a policy coverage for this but it is something business is going to start selling.
        "Number of Days" => number_of_days(coverage),
        "Premium with Taxes per Day" => format_monetary_field(premium_with_taxes_per_day(coverage)),
        "Premium with Taxes" => format_monetary_field(premium_with_taxes(coverage))
      }
    end

    def premium_with_taxes(coverage)
      return 0 if coverage.policy_premiums.blank?

      coverage.policy_premiums.last.total
    end

    def premium_with_taxes_per_day(coverage)
      days = number_of_days(coverage)

      days == 0 ? 0 : premium_with_taxes(coverage) / days
    end

    # NOTE: This is only listed if coverage ends for a resident/address within the reporting period, otherwise it is left blank
    def end_date(coverage)
      return nil unless range_start && range_end && coverage.expiration_date

      coverage.expiration_date.in?(range_start..range_end) ? coverage.expiration_date : nil
    end

    # NOTE: The number of days of coverage for a given reporting period for the listed resident/address
    def number_of_days(coverage)
      return 0 unless coverage.expiration_date && coverage.effective_date

      from_date = coverage.effective_date
      to_date = end_date(coverage) || coverage.expiration_date

      (to_date - from_date).to_i
    end

    def master_liability(master_policy)
      master_policy.policy_coverages.where(designation: 'liability_coverage').last&.occurrence_limit || 0
    end

    def master_aggregate(master_policy)
      master_policy.policy_coverages.where(designation: '').last&.limit || 0
    end

    def premises_liability_coverage_limit(master_policy)
      master_policy.policy_coverages.where(designation: 'bodily_injury').last&.occurrence_limit || 0
    end

    def contents_amount(master_policy)
      master_policy.policy_coverages.where(designation: 'tenants_contingent_contents').last&.occurrence_limit || 0
    end

    def contents_coverage(master_policy)
      master_policy.policy_coverages.where(designation: 'tenants_contingent_contents').last&.enabled
    end

    def property_name(primary_insurable)
      primary_insurable.parent_community&.title || primary_insurable.account&.title
    end

    def property_id(primary_insurable)
      primary_insurable.parent_community&.id
    end

    def format_monetary_field(value)
      "$#{format('%.2f', value.to_i / 100.0)}"
    end
  end
end
