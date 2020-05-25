##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController

      before_action :set_policy, only: [:update, :show]
      before_action :set_substrate, only: [:create]
      
      def index
        @master_policies = current_staff.organizable.policies.where(policy_type_id: 2) || []
        if @master_policies.present?
          render json: @master_policies, status: :ok
        else
          render json: { message: 'No master policies' }
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @carrier = Carrier.find(params[:carrier_id])
          @policy_type = @carrier.policy_types.create!(policy_type: PolicyType.find(2))

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
            render :show, status: :ok
          else
            render json: @policy.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      private

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
          :expiration_date, :number, :policy_type_id, :status,
          policy_insurables_attributes: [ :insurable_id ],
          policy_users_attributes: [ :user_id ],
          policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                              :limit, :deductible, :enabled, :designation ]
        )
        return(to_return)
      end

      def create_policy_premium
        return({}) if params.blank?
        params.permit(:base:, :special_premium, :taxes,
          :billing_strategy, :policy_quote
        )
      end

      def update_params
        return({}) if params[:policy].blank?
        params.require(:policy).permit(
          :account_id, :agency_id, :auto_renew, :cancellation_code,
          :cancellation_date_date, :carrier_id, :effective_date,
          :expiration_date, :number, :policy_type_id, :status,
          policy_insurables_attributes: [ :insurable_id ],
          policy_users_attributes: [ :user_id ],
          policy_coverages_attributes: [ :id, :policy_application_id, :policy_id,
                              :limit, :deductible, :enabled, :designation ]
        )
      end
    end
  end # module StaffAgency
end
