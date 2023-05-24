module Qbe
  module Renewal
    # Qbe::Renewal::Prepare service
    class Prepare < ApplicationService

      attr_accessor :policy

      def initialize(policy)
        @policy = policy
      end

      def call
        raise "Policy null" if @policy.nil?
        raise "Policy record mismatch" unless @policy.is_a?(Policy)

        if @policy.update renewal_status: 'PREPARING'
          rate_refresh = Qbe::Renewal::RefreshRates.call(@policy)
          build_invoices_for_term = true

          if rate_refresh && build_invoices_for_term
            @policy.update renewal_status: 'PREPARED'
          else
            @policy.update renewal_status: 'PREPARATION_FAILED'
          end
        else
          @policy.update renewal_status: 'PREPARATION_FAILED'
        end
      end

    end
  end
end
