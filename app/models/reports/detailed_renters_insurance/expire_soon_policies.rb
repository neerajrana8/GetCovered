module Reports
  module DetailedRentersInsurance
    class ExpireSoonPolicies < ::Report

      private

      def headers
        %w[address primary_user policy_type policy expiration_date]
      end
    end
  end
end
