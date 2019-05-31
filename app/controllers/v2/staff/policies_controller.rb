module V2
  module Staff
    class PoliciesController < StaffController
      before_action :set_policy,
        only: :show

      def index
        if params[:short]
          super(:@policies, @account.policies)
        else
          super(:@policies, @account.policies, :carrier, user: :profile, unit: { building: :community })
        end
      end

      def show
      end

      def create
        @policy = Policy.new_external_policy(policy_params.merge({
          account: @account,
          agency: @account.agency
        }))
        if @policy.save_as(current_staff)
          render :show, status: :created
        else
          render json: @policy.errors,
            status: :unprocessable_entity
        end
      end

      private

        def view_path
          super + '/policies'
        end

        def policy_params
          koverage_krapp = [:hurricane, :pet_damage, :theft, :wind_hail, :coverage_c, :coverage_d, :coverage_e, :coverage_f]
          params.require(:policy)
                .permit(:carrier_id, :unit_id, :user_id,
                        :effective_date, :expiration_date, :number_insured, :total_premium,
                        :liability_only, carrier_data: [:carrier_name], deductibles: koverage_krapp, coverage_limits: koverage_krapp)
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            policy_number: [ :scalar, :array, :like ],
            effective_date: [:scalar, :array, :interval],
            expiration_date: [:scalar, :array, :interval],
            last_payment_date: [:scalar, :array, :interval],
            next_payment_date: [:scalar, :array, :interval],
            auto_renewal: [:scalar],
            renewal_count: [:scalar],
            last_renewed_on: [:scalar, :array, :interval],
            original_expiration_date: [:scalar, :array, :interval],
            billing_status: [:scalar, :array],
            billing_interval: [:scalar, :array],
            billing_behind_since: [:scalar, :array, :interval],
            status: [:scalar, :array],
            billing_enabled: [:scalar],
            user_in_system: [:scalar],
            policy_in_system: [:scalar],
            unit_id: [:scalar, :array],
            user_id: [:scalar, :array],
            carrier_id: [:scalar, :array],
            user: {
              id: [ :scalar, :array ],
              email: [ :scalar, :array, :like ],
              guest: [ :scalar ],
              profile: {
                first_name: [ :scalar ],
                last_name: [ :scalar ]
              }
            }
          }
        end

        def set_policy
          @policy = @account.policies.find(params[:id])
        end

    end
  end
end
