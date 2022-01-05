##
# V2 StaffSuperAdmin Carriers Controller
# File: app/controllers/v2/staff_super_admin/carriers_controller.rb

module V2
  module StaffSuperAdmin
    class CarriersController < StaffSuperAdminController
      include FeesMethods
      include Carriers::CommissionsMethods

      before_action :set_carrier, only: %i[update show available_agencies]
      before_action :set_substrate, only: %i[create index]

      def index

        super(:@carriers, @substrate)
        render template: 'v2/shared/carriers/index', status: :ok
      end

      def carrier_agencies
        carrier_agencies = paginator(Carrier.find(params[:id]).agencies)
        render json: carrier_agencies, status: :ok
      end

      def available_agencies
        result          = []
        required_fields = %i[id title agency_id enabled]

        agencies =
          Agency.
            includes(carrier_agencies: :carrier_agency_policy_types).
            where(agencies: { agency_id: nil })


        agencies.select(required_fields).each do |agency|
          carrier_agency = agency.carrier_agencies.find_by(carrier: @carrier)
          result <<
            if carrier_agency.present? && agency.agencies.any?
              sub_agencies = agency.agencies.select(required_fields)
              available_sub_agencies =
                sub_agencies.select do |subagency|
                  subagency.carrier_agencies.find_by(carrier: @carrier).nil?
                end.map(&:attributes)

              if available_sub_agencies.any?
                agency.attributes.reverse_merge(
                  agencies: available_sub_agencies,
                  available_policy_types: carrier_agency.carrier_agency_policy_types.pluck(:policy_type_id),
                  already_assigned: true
                )
              end
            else
              agency.attributes.reverse_merge(already_assigned: false)
            end
        end

        render json: result.compact.to_json
      end

      def show
        render template: 'v2/shared/carriers/show', status: :ok
      end

      def create
        if create_allowed?
          ActiveRecord::Base.transaction do
            @carrier = Carrier.create(create_params)
            @carrier.get_or_create_universal_parent_commission_strategy if create_params[:commission_strategy_attributes].nil?
            if @carrier.errors.blank? && @carrier.update(init_types_params)
              render template: 'v2/shared/carriers/show', status: :created
            else
              render json: standard_error(:carrier_creation_error, nil, @carrier.errors.full_messages),
                     status: :unprocessable_entity
            end
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def assign_agency_to_carrier
        agency = Agency.find_by(id: assign_to_carrier_params[:agency_id])
        carrier = Carrier.find_by(id: assign_to_carrier_params[:carrier_id])

        unless agency.nil? || carrier.nil?
          if carrier.agencies.include?(agency)
            render json: { message: 'This agency has been already assigned to this carrier' }, status: :unprocessable_entity
          else
            created = ::CarrierAgency.create(assign_to_carrier_params)
            if created.id
              render json: { message: 'Carrier was added to the agency' }, status: :ok
            else
              render json: standard_error(:something_went_wrong, "#{agency.title} could not be assigned to #{carrier.title}", created.errors.full_messages), status: :unprocessable_entity
            end
          end
        end
      end

      def billing_strategies_list
        @billing_strategies =
          if params[:carrier_agency_id].present?
            paginator(BillingStrategy.includes(:agency).where(carrier_id: params[:id], agency_id: params[:carrier_agency_id]).order(created_at: :desc))
          else
            paginator(BillingStrategy.includes(:agency).where(carrier_id: params[:id]).order(created_at: :desc))
          end
        render 'v2/shared/billing_strategies/index'
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

      def unassign_agency_from_carrier
        carrier = Carrier.find(params[:id])
        agency = carrier.agencies.find_by(id: params[:carrier_agency_id])
        CarrierAgency.find_by(agency_id: agency.id, carrier_id: carrier).destroy
        render json: { message: 'Agency was successfully unassigned' }
      end

      def update
        if update_allowed?
          if update_params[:commission_strategy_attributes].nil? && @carrier.commission_strategy.nil?
            @carrier.get_or_create_universal_parent_commission_strategy
          end
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
      
      def assign_to_carrier_params
        params.require(:carrier_agency).permit(
          :carrier_id,
          :agency_id,
          :external_carrier_id,
          carrier_agency_policy_types_attributes: [
            :policy_type_id,
            commission_strategy_attributes: [
              :percentage
            ]
          ]
        )
      end

      def create_params
        return({}) if params[:carrier].blank?

        to_return = params.require(:carrier).permit(
          :bindable, :call_sign, :enabled, :id,
          :integration_designation, :quotable, :rateable, :syncable,
          :title, :verifiable, settings: {}
        )
        to_return
      end

      def init_types_params
        return({}) if params[:carrier].blank?

        to_return = params.require(:carrier).permit(
          carrier_policy_types_attributes: [
           :policy_type_id,
           commission_strategy_attributes: [:percentage],
           carrier_policy_type_availabilities_attributes: %i[state available zip_code_blacklist]
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
            commission_strategy_attributes: [:percentage],
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
          carrier_policy_types: {
            policy_type_id: %i[scalar array]
          }
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
    end
  end # module StaffSuperAdmin
end
