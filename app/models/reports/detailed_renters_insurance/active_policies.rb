module Reports
  module DetailedRentersInsurance
    class ActivePolicies < ::Report

      private

      def headers
        %w[address primary_user policy_type policy contents liability]
      end
    end
  end
end
