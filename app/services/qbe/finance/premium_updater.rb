module Qbe
  module Finance
    # Qbe::Finance::PremiumUpdater
    class PremiumUpdater < ApplicationService

      attr_accessor :policy_premium
      attr_accessor :new_premium
      attr_accessor :change_date

      def initialize
        @policy_premium = policy_premium
        @new_premium = new_premium
        @change_date = change_date
      end

      def call
        update_attempt = {
          :status => false,
          :message => "No Progress",
          :data => nil
        }

        formatted_premium = @new_premium.nil? ? nil : @new_premium.to_i * 100
        premium_difference = @new_premium.nil? ? nil : formatted_premium - @policy_premium.total_premium
        unless premium_difference == 0
          begin
            ppi = @policy_premium.policy_premium_items
                                 .where(category: 'premium', proration_refunds_allowed: true)
                                 .take

            ppi.change_remaining_total_by(premium_difference, @change_date,
                                          clamp_start_date_to_effective_date: false,
                                          clamp_start_date_to_today: false,
                                          clamp_start_date_to_first: false)
          rescue Exception => e
            update_attempt[:message] = "Exception occurred"
            update_attempt[:data] = e
          end
        else
          update_attempt[:status] = true
          update_attempt[:message] = "No difference detected"
        end

        return update_attempt
      end

    end
  end
end