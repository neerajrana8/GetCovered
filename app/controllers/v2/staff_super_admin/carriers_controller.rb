##
# V2 StaffSuperAdmin Carriers Controller
# File: app/controllers/v2/staff_super_admin/carriers_controller.rb

module V2
  module StaffSuperAdmin
    class CarriersController < StaffSuperAdminController
      include Carriers::Fees

      before_action :set_carrier, only: %i[update show]
      
      before_action :set_substrate, only: %i[create index]
      
      def index
        super(:@carriers, @substrate)
        render template: 'v2/shared/carriers/index', status: :ok
      end

      def carrier_agencies
        carrier_agencies = paginator(Carrier.find(params[:id]).agencies)
        render json: carrier_agencies, status: :ok
      end
      
      def show
        render template: 'v2/shared/carriers/show', status: :ok
      end
      
      def create
        if create_allowed?
          @carrier = Carrier.create(create_params)
          if @carrier.errors.blank?
            render template: 'v2/shared/carriers/show', status: :created
          else
            render json: standard_error(:carrier_creation_error, nil, @carrier.errors.full_messages),
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def assign_agency_to_carrier
        agency = Agency.find_by(id: params[:carrier_agency_id])
        carrier = Carrier.find_by(id: params[:id])
        policy_types = carrier.policy_types
        carrier_agency = carrier.agencies
        if carrier_agency.exists?(agency.id)
          render json: { message: 'This agency has been already assigned to this carrier' }, status: :unprocessable_entity
        else
          carrier_agency << agency
          policy_types.each do |policy_type|
            BillingStrategy.create(carrier: carrier, agency: agency,
                                   title: 'Monthly', enabled: true, policy_type: policy_type,
                                   new_business: {
                                     'payments' => [
                                       8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33
                                     ],
                                     'payments_per_term' => 12,
                                     'remainder_added_to_deposit' => true
                                   })
            BillingStrategy.create(carrier: carrier, agency: agency,
                                   title: 'Quarterly', enabled: true, policy_type: policy_type,
                                   new_business: {
                                     'payments' => [
                                       25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0
                                     ],
                                     'payments_per_term' => 4,
                                     'remainder_added_to_deposit' => true
                                   })
            BillingStrategy.create(carrier: carrier, agency: agency,
                                   title: 'Annually', enabled: true, policy_type: policy_type,
                                   new_business: {
                                     'payments' => [
                                       100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                                     ],
                                     'payments_per_term' => 1,
                                     'remainder_added_to_deposit' => true
                                   })
            BillingStrategy.create(carrier: carrier, agency: agency,
                                   title: 'Bi-Annually', enabled: true, policy_type: policy_type,
                                   new_business: {
                                     'payments' => [
                                       50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0
                                     ],
                                     'payments_per_term' => 2,
                                     'remainder_added_to_deposit' => true
                                   })
          end
          render json: { message: 'Carrier was added to the agency' }, status: :ok
        end
      end

      def billing_strategies_list
        if params[:carrier_agency_id].present?
          billing_strategies = paginator(BillingStrategy.where(carrier_id: params[:id], agency_id: params[:carrier_agency_id]).order(created_at: :desc))
          render json: billing_strategies, status: :ok
        else
          billing_strategies = paginator(BillingStrategy.where(carrier_id: params[:id]).order(created_at: :desc))
          render json: billing_strategies, status: :ok
        end
      end

      def toggle_billing_strategy
        billing_strategy = BillingStrategy.find_by(id: params[:billing_strategy_id], carrier_id: params[:id])
        billing_strategy.toggle(:enabled).save
        if billing_strategy.enabled?
          render json: { message: 'Billing strategy is switched on' }, status: :ok
        else
          render json: { message: 'Billing strategy is switched off' }, status: :ok
        end
      end

      def add_commissions
        commission_strategy = CommissionStrategy.new(commission_params)
        if commission_strategy.save
          render json: { message: 'Commission was successfully added' }, status: :ok
        else
          render json: { message: 'Commission was not created' }, status: :unprocessable_entity
        end
      end

      def update_commission
        commission = CommissionStrategy.find(params[:commission_id])
        if commission.update(commission_params)
          render json: { message: 'Commission was successfully updated' }, status: :ok
        else
          render json: { message: 'Commission was not updated' }, status: :unprocessable_entity
        end
      end

      def unassign_agency_from_carrier
        carrier = Carrier.find(params[:id])
        agency = carrier.agencies.find_by(id: params[:carrier_agency_id])
        CarrierAgency.find_by(agency_id: agency.id, carrier_id: carrier).destroy
        render json: { message: 'Agency was successfully unassign' }
      end

      def commission_list
        if params[:carrier_agency_id].present?
          commissions = paginator(CommissionStrategy.where(carrier_id: params[:id], commissionable_id: params[:carrier_agency_id]).order(created_at: :desc))
          render json: commissions, status: :ok
        else
          commissions = paginator(CommissionStrategy.where(carrier_id: params[:id]).order(created_at: :desc))
          render json: commissions, status: :ok
        end
      end

      def commission
        if params[:commission_id].present?
          commission = CommissionStrategy.find(params[:commission_id])
          render json: commission, status: :ok
        else
          render json: { message: 'Something went wrong' }, status: :unprocessable_entity
        end
      end
      
      def update
        if update_allowed?
          if @carrier.update(update_params)
            render template: 'v2/shared/carriers/show', status: :ok
          else
            render json: @carrier.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      private
      
      def view_path
        super + '/carriers'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def set_carrier
        @carrier = access_model(::Carrier, params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Carrier)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.carriers
        end
      end
        
      def create_params
        return({}) if params[:carrier].blank?

        to_return = params.require(:carrier).permit(
          :bindable, :call_sign, :enabled, :id,
          :integration_designation, :quotable, :rateable, :syncable,
          :title, :verifiable, settings: {}, 
                               carrier_policy_types_attributes: [
                                 :policy_type_id, carrier_policy_type_availabilities_attributes: %i[state available zip_code_blacklist]
                               ]
        )
        to_return
      end
        
      def update_params
        return({}) if params[:carrier].blank?

        to_return = params.require(:carrier).permit(
          :bindable, :call_sign, :enabled, :id,
          :integration_designation, :quotable, :rateable, :syncable,
          :title, :verifiable, 
          settings: {}, carrier_policy_types_attributes: [
            :id, :policy_type_id,
            carrier_policy_type_availabilities_attributes: %i[id state available zip_code_blacklist]
          ]
        )

        existed_ids = to_return[:carrier_policy_types_attributes]&.map { |cpt| cpt[:id] }

        unless @carrier.blank? || existed_ids.nil?
          (@carrier.carrier_policy_types.pluck(:id) - existed_ids).each do |id|
            to_return[:carrier_policy_types_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def billing_strategy_params
        params.permit(:agency, :fee,
                      :carrier, :policy_type, :title,
                      :new_business)
      end

      def fee_params
        params.permit(:title, :type,
                      :per_payment, :amortize,
                      :amount, :enabled,
                      :ownerable_id, :assignable_id)
      end

      def commission_params
        params.permit(:title, :amount,
                      :type, :fulfillment_schedule,
                      :amortize, :per_payment,
                      :enabled, :locked, :house_override,
                      :override_type, :carrier_id,
                      :policy_type_id, :commissionable_type,
                      :commissionable_id, :percentage,
                      :commission_strategy_id)
      end
    end
  end # module StaffSuperAdmin
end
