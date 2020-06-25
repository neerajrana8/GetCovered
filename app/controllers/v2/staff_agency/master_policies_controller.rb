##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController
      before_action :set_policy, only: [:update, :show, :show_create]
      before_action :set_substrate, only: [:create]
      
      def index
        @master_policies = Policy.where('policy_type_id = ? AND agency_id = ?', 2, @agency.id) || []
      end
      
      def show
        @master_policy = Policy.find_by(policy_type_id: 2, id: params[:id])
        @master_policy_coverages = @master_policy.policies.where('policy_type_id = ? AND agency_id = ?', 3, @agency.id) || []
      end

      def show_create
        policy = Policy.find(params[:id])
        carrier_agency = CarrierAgency.find_by(params[:carrier_id])
        account = carrier_agency.agency.accounts.find_by(params[:account_id])
        if insurable = account.insurables.communities.create!(insurable_type_id: params[:insurable_type_id], title: params[:title])
          PolicyInsurable.create!(insurable: insurable, policy_id: policy.id)
          render json: { message: 'Community added' }, status: :ok
        else
          render json: { errors: @policy.errors.merge(@policy_premium.errors) }, status: :unprocessable_entity
        end
      end
        
      
      def create
        if create_allowed?
          policy_type = PolicyType.find(2)
          carrier = Carrier.find(params[:carrier_id])
          carrier_agency = CarrierAgency.find(carrier.id)
          account = carrier_agency.agency.accounts.find(params[:account_id])

          @policy = @substrate.new(create_params.merge(agency: carrier_agency.agency,
                                   carrier: carrier, account: account, policy_type: policy_type))
          @policy_premium = PolicyPremium.new(create_policy_premium)
          if @policy.errors.none? && @policy_premium.errors.none? && @policy.save && @policy_premium.save
            render json: { message: 'Master Policy and Policy Premium created' }, status: :created
            AutomaticMasterPolicyInvoiceJob.perform_later(@policy.id)
          else
            render json: { errors: @policy.errors.merge(@policy_premium.errors) }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          @policy.update(cancellation_date_date: params[:date])
          if @policy.cancellation_date_date.present?
            AutomaticMasterPolicyInvoiceJob.perform_later(@policy.id)
            render json: { message: 'Master policy canceled' }, status: :ok
          elsif @policy.cancellation_date_date.nil?
            render json: { message: 'Master policy not canceled' }, status: :ok
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
        params.permit(:base, :total, :calculation_base,
          :carrier_base
        )
      end
    end
  end # module StaffAgency
end
