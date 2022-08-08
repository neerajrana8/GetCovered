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
  class PendingCancelPolicies < ::Report
    NAME = 'Pending cancel policies'.freeze

    def generate
      reportable_policies&.each do |policy|
        insurable = policy.primary_insurable
        insurable_address = insurable&.primary_address
        primary_policy_user = policy&.primary_user&.profile
        self.data['rows'] << {
          'management_company' => policy.account.title,
          'property_name' => insurable_address&.full,
          'property_city' => insurable_address&.city,
          'property_state' => insurable_address&.state,
          'property_phone' => nil,
          'policy_type' => 'H04',
          'policy_number' => policy.number,
          'primary_insured_name' => primary_policy_user&.full_name,
          'primary_insured_phone' => primary_policy_user&.contact_phone,
          'primary_insured_email' => primary_policy_user&.contact_email,
          'primary_insurance_location' => insurable_address&.full,
          'effective_date' => policy.effective_date,
          'expiration_date' => policy.expiration_date,
          'finished_date' => policy.expiration_date
        }
      end
      self
    end

    def column_names
      {
        'management_company' => 'Management Company',
        'property_name' => 'Property Name',
        'property_city' => 'Property City',
        'property_state' => 'Property State',
        'property_phone' => 'Property Phone',
        'policy_type' => 'Policy Type',
        'policy_number' => 'Policy Number',
        'primary_insured_name' => 'Primary Insured Name',
        'primary_insured_phone' => 'Primary Insured Phone',
        'primary_insured_email' => 'Primary Insured Email',
        'primary_insurance_location' => 'Primary Insurance Location',
        'effective_date' => 'Effective date',
        'expiration_date' => 'Expiration date',
        'finished_date' => 'Finished date'
      }
    end

    def headers
      %w[management_company property_name property_city property_state property_phone policy_type
         policy_number primary_insured_name primary_insured_phone primary_insured_email
         primary_insurance_location effective_date expiration_date finished_date]
    end

    private

    def reportable_policies
      units =
        if reportable.is_a?(Insurable)
          reportable.units
        else
          reportable.insurables.units
        end

      units&.map do |unit|
        policy = unit.policies.take
        next if policy.blank?
        if policy.billing_status == 'BEHIND'
          policy
        end
      end&.uniq&.compact
    end

    def set_defaults
      self.data ||= { rows:[] }
    end
  end
end
