##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffSuperAdmin
    class PoliciesController < StaffSuperAdminController
      
      before_action :set_policy, only: [:show, :refund_policy, :cancel_policy]
      
      before_action :set_substrate, only: [:index]
      
      def index
        super(:@policies, @substrate)
      end
      
      def show
      end
      
      def search
        @policies = Policy.search(params[:query]).records
        render json: @policies.to_json, status: 200
      end

      def refund_policy
        @policy.cancel('manual_cancellation_with_refunds', Time.zone.now)
        if @policy.errors.any?
          render json: standard_error(:refund_policy_error, nil, @policy.errors.full_messages)
        else
          render :show, status: :ok
        end
      end

      def cancel_policy
        @policy.cancel('manual_cancellation_without_refunds', Time.zone.now)
        if @policy.errors.any?
          render json: standard_error(:cancel_policy_error, nil, @policy.errors.full_messages)
        else
          render :show, status: :ok
        end
      end

      private
      
        def view_path
          super + "/policies"
        end
        
        def set_policy
          @policy = access_model(::Policy, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Policy)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policies
          end
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
            id: %i[scalar array],
            carrier: {
              id: %i[scalar array],
              title: %i[scalar like]
            },
            number: %i[scalar like],
            policy_type_id: %i[scalar array],
            status: %i[scalar like],
            created_at: %i[scalar like],
            updated_at: %i[scalar like],
            policy_in_system: %i[scalar like],
            effective_date: %i[scalar like],
            expiration_date: %i[scalar like]
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffSuperAdmin
end
