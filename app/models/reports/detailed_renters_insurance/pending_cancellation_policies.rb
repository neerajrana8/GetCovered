module Reports
  module DetailedRentersInsurance
    class PendingCancellationPolicies < ::Report

      private

      def headers
        %w[address primary_user policy_type policy cancel_reason pending_cancel_date]
      end
    end
  end
end
