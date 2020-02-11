module Reports
  module DetailedRentersInsurance
    class PendingCancellationPolicies < ::Report

      def generate
        units = reportable.insurables.units
        if units.present?
          units.covered.each do |insurable|
            policy = insurable.policies.take

            if policy.present? && policy.billing_status == :BEHIND
              data['rows'] << {
                address: insurable.title,
                primary_user: policy.primary_user&.profile&.full_name,
                policy_type: 'H04',
                policy: policy.number,
                cancel_reason: 'Behind billing',
                pending_cancel_date: policy
              }
            end
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows:[] }
      end

      def headers
        %w[address primary_user policy_type policy cancel_reason pending_cancel_date]
      end
    end
  end
end
