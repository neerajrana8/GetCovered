module Reports
  class RenewalPolicies < ::Report
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
          'renewal_effective_date' => policy.effective_date,
          'renewal_expiration_date' => policy.expiration_date
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
        'renewal_effective_date' => 'Renewal effective date',
        'renewal_expiration_date' => 'Renewal expiration date'
      }
    end

    def headers
      %w[management_company property_name property_city property_state property_phone policy_type
         policy_number primary_insured_name primary_insured_phone primary_insured_email
         primary_insurance_location renewal_effective_date renewal_expiration_date]
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
        policy if renewal?(policy)
      end&.uniq&.compact
    end

    def renewal?(policy)
      policy.cancellation_date_date&.between?(range_start, range_end) ||
        policy.billing_behind_since&.between?(range_start, range_end) ||
        (policy.auto_renew == false && policy.expiration_date&.between?(range_start, range_end))
    end

    def set_defaults
      self.data ||= { rows:[] }
    end
  end
end
