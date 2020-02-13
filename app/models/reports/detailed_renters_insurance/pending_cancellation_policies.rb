module Reports
  module DetailedRentersInsurance
    class PendingCancellationPolicies < ::Report

      # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
      # I planned to make reports "class agnostic".
      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units
          else
            reportable.insurables.units
          end

        units&.covered&.each do |insurable|
          policy = insurable.policies.take

          if policy.present? && policy.billing_status == :BEHIND
            self.data['rows'] << {
              address: insurable.title,
              primary_user: policy.primary_user&.profile&.full_name,
              policy_type: 'H04',
              policy: policy.number,
              cancel_reason: 'Behind billing',
              pending_cancel_date: policy
            }
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end

      def headers
        %w[address primary_user policy_type policy cancel_reason pending_cancel_date]
      end
    end
  end
end
