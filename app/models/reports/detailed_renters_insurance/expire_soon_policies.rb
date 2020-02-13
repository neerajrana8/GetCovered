module Reports
  module DetailedRentersInsurance
    class ExpireSoonPolicies < ::Report

      # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
      # I planned to make reports "class agnostic".
      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units
          else
            reportable.insurables.units
          end
        units&.each do |unit|
          policy = unit.policies.take
          if (policy&.auto_renew == false) && (policy&.expiration_date < Time.current + 30.days)
            self.data['rows'] << {
              address: unit.title,
              primary_user: policy.primary_user&.profile&.full_name,
              policy_type: 'H04',
              policy: policy.number,
              expiration_date: policy.expiration_date
            }
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows:[] }
      end

      def headers
        %w[address primary_user policy_type policy expiration_date]
      end
    end
  end
end
