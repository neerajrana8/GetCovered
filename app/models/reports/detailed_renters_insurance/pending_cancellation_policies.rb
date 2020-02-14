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
              'address' => insurable.title,
              'primary_user' => policy.primary_user&.profile&.full_name,
              'policy_type' => 'H04',
              'policy' => policy.number,
              'cancel_reason' => 'Behind billing',
              'pending_cancel_date' => policy
            }
          end
        end
        self
      end

      def column_names
        {
          'address' => 'Address',
          'primary_user' => 'User',
          'policy_type' => 'Policy type',
          'policy' => 'Policy number',
          'cancel_reason' => 'Cancel reason',
          'pending_cancel_date' => 'Cancel date',
        }
      end

      def headers
        %w[address primary_user policy_type policy cancel_reason pending_cancel_date]
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end
    end
  end
end
