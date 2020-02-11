module Reports
  module DetailedRentersInsurance
    class CancelledPolicies < ::Report

      def generate
        insurable_community.units&.each do |unit|
          policy = unit.policies.take
          if policy&.status == 'CANCELLED'
            data['rows'] << {
              address: unit.title,
              primary_user: policy.primary_user&.profile&.full_name,
              policy_type: 'H04',
              policy: policy.number,
              cancel_reason: 'Non Payment',
              cancel_date: policy.cancellation_date_date
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
        %w[address primary_user policy_type policy cancel_reason cancel_date]
      end
    end
  end
end
