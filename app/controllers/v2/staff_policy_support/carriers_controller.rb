##
# V2 StaffPolicySupport Carriers Controller
# File: app/controllers/v2/staff_policy_support/carriers_controller.rb

module V2
  module StaffPolicySupport
    class CarriersController < StaffPolicySupportController
      before_action :set_substrate, only: %i[index]

      def index
        super(:@carriers, @substrate)
        @carriers = @carriers.order(title: :asc)
        render template: 'v2/shared/carriers/index', status: :ok
      end

      private

      def set_substrate
        @substrate = Carrier.all
      end
    end
  end
end
