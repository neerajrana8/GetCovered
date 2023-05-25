module Qbe
  module Finance
    # Qbe::Finance::PremiumUpdater
    class PremiumUpdater < ApplicationService

      attr_accessor :policy_premium
      attr_accessor :new_premium

      def initialize
        @policy_premium = policy_premium
        @new_premium = new_premium
      end

      def call

      end

    end
  end
end