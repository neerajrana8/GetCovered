##
# V2 StaffAccount Policies Controller
# File: app/controllers/v2/staff_account/policies_controller.rb

module V2
  module StaffAccount
    class PoliciesController < StaffAccountController
      
      before_action :set_policy, only: [:update, :show]
      
      before_action :set_substrate, only: [:create, :index]
      
      def index
        super(:@policies, @substrate)
      end

      def search
        @policies = Policy.search(params[:query]).records.where(account_id: current_staff.organizable_id)
        render json: @policies.to_json, status: 200
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @policy = @substrate.new(create_params)
          if @policy.errors.none? && @policy.save
            render :show, status: :created
          else
            render json: @policy.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @policy.update(update_params)
            render :show,
              status: :ok
          else
            render json: @policy.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      
      private
      
        def view_path
          super + "/policies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
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
        
        def create_params
          return({}) if params[:policy].blank?
          to_return = params.require(:policy).permit(
            :account_id, :agency_id, :auto_renew, :cancellation_code,
            :cancellation_date_date, :carrier_id, :effective_date,
            :expiration_date, :number, :policy_type_id, :status, :document,
            policy_insurables_attributes: [ :insurable_id ],
            policy_users_attributes: [ :user_id ],
            policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                                :limit, :deductible, :enabled, :designation ]
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:policy].blank?
          params.require(:policy).permit(
            :account_id, :agency_id, :auto_renew, :cancellation_code,
            :cancellation_date_date, :carrier_id, :effective_date,
            :expiration_date, :number, :policy_type_id, :status, :document,
            policy_insurables_attributes: [ :insurable_id ],
            policy_users_attributes: [ :user_id ],
            policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                                :limit, :deductible, :enabled, :designation ]
          )
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
            id: %i[scalar array],
            carrier: {
              id: %i[scalar array],
              title: %i[scalar like]
            },
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
  end # module StaffAccount
end
