# frozen_string_literal: true

module V2
  module Staff
    class PaymentsController < StaffController
      before_action :set_payment, only: :show, if: -> { current_staff.agent? }

      def index
        if params[:short]
          super(:@payments, @scope_association.payments)
        else
          super(:@payments, @scope_association.payments, :policy, user: :profile)
        end
      end

      def show; end

      private

      def view_path
        super + '/payments'
      end

      def supported_filters
        {
          id: %i[scalar array],
          status: %i[scalar array],
          amount: %i[scalar array interval],
          amount_refunded: %i[scalar array interval],
          user_in_system: [:scalar],
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
          invoice_id: %i[scalar array],
          invoice: {
            id: %i[scalar array],
            due_date: %i[scalar array interval],
            policy_id: %i[scalar array],
            user_id: %i[scalar array],
            policy: {
              id: %i[scalar array],
              policy_number: %i[scalar array],
              account_id: %i[scalar array]
            },
            user: {
              id: %i[scalar array],
              guest: [:scalar],
              profile: {
                first_name: [:scalar],
                last_name: [:scalar]
              }
            }
          }
        }
      end

      def set_payment
        @payment = @scope_association.payments.find(params[:id])
      end
    end
  end
end
