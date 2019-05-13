##
# V1 Account Rates Controller
# file: app/controllers/v1/account/rates_controller.rb

module V1
  module Account
    class RatesController < StaffController
      before_action :set_rate,
        only: :show

      def index
        if params[:short]
          super(:@rates, @account.rates)
        else
          super(:@rates, @account.rates, :carrier, :community)
        end
      end

      def show
      end

      private

        def view_path
          super + '/rates'
        end

        def supported_filters
          {
            id: [:scalar, :array],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            schedule: [:scalar, :array],
            sub_schedule: [:scalar, :array],
            liability_only: [:scalar],
            number_insured: [:scalar, :array, :interval],
            interval: [:scalar, :array],
            premium: [:scalar, :array, :interval],
            period_premium: [:scalar, :array],
            activated: [:scalar],
            activated_on: [:scalar, :array, :interval],
            deactivated_on: [:scalar, :array, :interval],
            paid_in_full: [:scalar],
            carrier_id: [:scalar, :array],
            community_id: [:scalar, :array],
            carrier: {
              id: [:scalar, :array],
              title: [:scalar, :array]
            },
            community: {
              id: [:scalar, :array],
              name: [:scalar, :array],
              account_id: [:scalar, :array]
            }
          }
        end

        def set_rate
          @rate = @account.rates.find(params[:id])
        end
    end
  end
end
