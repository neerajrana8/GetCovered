module Reports
  module DetailedRentersInsurance
    class CancelledPolicies < ::Report

      private

      def headers
        %w[address primary_user policy_type policy cancel_reason cancel_date]
      end
    end
  end
end
