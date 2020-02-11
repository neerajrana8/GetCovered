module Reports
  module DetailedRentersInsurance
    class ActivePolicies < ::Report

      def generate
        units = reportable.insurables.units
        if units.present?
          units.covered.each do |insurable|
            policy = insurable.policies.take
            if policy.present?
              data['rows'] << {
                address: insurable.title,
                primary_user: policy.primary_user&.profile&.full_name,
                policy_type: 'H04',
                policy: policy.number,
                contents: policy.insurable_rates.coverage_c.last&.description,
                liability: policy.insurable_rates.liability.last&.description
              }
            end
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end

      def headers
        %w[address primary_user policy_type policy contents liability]
      end
    end
  end
end
