module Qbe
  module Renewal
    # Qbe::Renewal::RefreshRates service
    class RefreshRates < ApplicationService

      attr_accessor :policy

      def initialize(policy)
        @policy = policy
      end

      def call
        raise "Policy null" if @policy.nil?
        raise "Policy record mismatch" unless @policy.is_a?(Policy)

        return true
      end

    end
  end
end
