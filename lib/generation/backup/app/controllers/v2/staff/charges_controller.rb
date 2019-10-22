module V2
  module Staff
    class ChargesController < StaffController
      before_action :set_charge, only: :show
      before_action :only_super_admins, only: [:credit, :edit, :destroy]
      
      def index
        if params[:short]
          super(:@charges, @scope_association.charges)
        else
          super(:@charges, @scope_association.charges, :policy, user: :profile)
        end
      end

      def show
      end

      private

        def view_path
          super + '/charges'
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            status: [:scalar, :array],
            payment_method: [:scalar, :array],
            amount: [:scalar, :array, :interval],
            invoice_id: [:scalar, :array],
            invoice: {
              id: [:scalar, :array],
              created_at: [:scalar, :array, :interval],
              updated_at: [:scalar, :array, :interval],
              number: [:scalar, :array],
              status: [:scalar, :array],
              due_date: [:scalar, :array, :interval],
              total: [:scalar, :array, :interval],
              subtotal: [:scalar, :array, :interval],
              tax: [:scalar, :array, :interval],
              tax_percentage: [:scalar, :array, :interval],
              policy_id: [:scalar, :array],
              user_id: [:scalar, :array],
              policy: {
                id: [:scalar, :array],
                policy_number: [:scalar, :array],
                account_id: [:scalar, :array]
              },
              user: {
                id: [:scalar, :array],
                guest: [:scalar],
                profile: {
                  first_name: [:scalar],
                  last_name: [:scalar]
                }
              }
            }
          }
        end

        def set_charge
          if current_staff.super_admin?
            @charge = Charge.find(params[:id])
          else
            @charge = @scope_association.charges.find(params[:id])
          end
        end

    end
  end
end
