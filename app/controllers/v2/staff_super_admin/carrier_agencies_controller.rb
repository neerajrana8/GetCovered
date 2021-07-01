module V2
  module StaffSuperAdmin
    class CarrierAgenciesController < StaffSuperAdminController
      before_action :set_carrier_agency, only: %i[show update]

      def index
        super(:@carrier_agencies, CarrierAgency.all, :agency, :carrier)
        render template: 'v2/shared/carrier_agencies/index', status: :ok
      end

      def show
        render template: 'v2/shared/carrier_agencies/show', status: :ok
      end

      def create
        # Same as CarriersController#assign_agency_to_carrier...
        agency = Agency.find_by(id: create_params[:agency_id])
        carrier = Carrier.find_by(id: create_params[:carrier_id])
        unless agency.nil? || carrier.nil?
          if carrier.agencies.include?(agency)
            render json: { message: 'This agency has been already assigned to this carrier' }, status: :unprocessable_entity
          else
            created = ::CarrierAgency.create(create_params)
            if created.id
              render json: { message: 'Carrier was added to the agency' }, status: :ok
            else
              render json: standard_error(:something_went_wrong, "#{agency.title} could not be assigned to #{carrier.title}", created.errors.full_messages), status: :unprocessable_entity
            end
          end
        end
      end

      def update
        if @carrier_agency.update_as(current_staff, update_params)
          render template: 'v2/shared/carrier_agencies/show', status: :ok
        else
          render json: standard_error(:carrier_agency_update_errors, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end
      
      def parent_info
        # process parameters
        agency = Agency.where(id: parent_info_params[:agency_id]).take
        if agency.nil?
          render json standard_error(:agency_error, nil, "Agency with id #{parent_info_params[:agency_id] || 'null'} does not exist"),
            status: :unprocessable_entity
          return
        end
        ancestors = agency.get_ancestor_chain
        master_agency = Agency.where(master_agency: true).take
        ancestors.push(master_agency) unless ancestors.last == master_agency
        carrier = Carrier.where(id: parent_info_params[:carrier_id]).take
        if carrier.nil?
          render json standard_error(:carrier_error, nil, "Carrier with id #{parent_info_params[:carrier_id] || 'null'} does not exist"),
            status: :unprocessable_entity
          return
        end
        policy_type_ids = parent_info_params[:policy_type_ids].map{|ptid| ptid.to_i }.uniq
        policy_type_ids = ::CarrierPolicyType.where(carrier_id: carrier.id).pluck(:policy_type_id) if policy_type_ids.blank?
        # get CA if extant
        carrier_agency = ::CarrerAgency.where(carrier_id: carrier.id, agency_id: agency.id)
        # grab records
        all_capts = ::CarrierAgencyPolicyType.includes(:carrier_agency, :commission_strategy).references(:carrier_agencies, :commission_strategies)
                                             .where(carrier_agency: { carrier_id: carrier.id, agency_id: ancestors.map{|an| an.id } }, policy_type_id: policy_type_ids)
                                             .group_by{|capt| capt.policy_type_id }
                                             .transform_values{|capts| capts.sort_by{|capt| ancestors.find_index{|ag| ag.id == capt.carrier_agency.agency_id } }[0..1] }
        to_return = policy_type_ids.map do |ptid|
          capts = all_capts[ptid]
          if capts.blank?
            # not even GC has been set up for this policy type/carrier combo yet
            {
              status: 'nothing_exists',
              missing_agency_chain: ancestors.map{|ag| ag.id }
            }
          elsif capts[0].carrier_agency.agency_id == agency.id
            # the CAPT already exists
            current_children = capts[0].child_carrier_agency_policy_types(true)
            {
              status: 'record_exists',
              carrier_agency_id: capts[0].carrier_agency_id,
              carrier_agency_policy_type_id: capts[0].id,
              missing_agency_chain: nil,
              commission_current: capts[0].commission_strategy&.percentage,
              commission_max: capts[1]&.commission_strategy&.percentage || 100,
              commission_min: current_children.map{|capt| capt.commission_strategy&.percentage }.compact.max 0,
              can_disable: current_children.blank?,
              child_carrier_agency_policy_type_ids: current_children.map{|cc| cc.id }
            }
          elsif capts[0].carrier_agency.agency_id == (agency.agency_id || (agency.master_agency ? nil : master_agency))
            # the parent agency has a corresponding CAPT
            {
              status: 'parent_exists',
              parent_agency_id: capts[0].carrier_agency.agency_id,
              parent_agency_title: ancestors[1].title,
              parent_carrier_agency_id: capts[0].carrier_agency_id,
              parent_carrier_agency_policy_type_id: capts[0].id,
              missing_agency_chain: [agency.id],
              commission_max: capts[0].commission_strategy&.percentage,
              commission_min: 0
            }
          else
            # some non-immediate ancestor has a corresponding CAPT
            ancestor_index = ancestors.find_index{|ag| ag.id == capts[0].carrier_agency.agency_id }
            {
              status: 'ancestor_exists',
              ancestor_agency_id: capts[0].carrier_agency.agency_id,
              ancestor_agency_title: ancestors[ancestor_index].title,
              ancestor_carrier_agency_id: capts[0].carrier_agency_id,
              ancestor_carrier_agency_policy_type_id: capts[0].id,
              missing_agency_chain: ancestors[0...ancestor_index].map{|ag| ag.id },
              commission_max: capts[0].commission_strategy&.percentage,
              commission_min: 0
            }
          end
        end
        # note CPT existence instead of 'nothing_exists' where appropriate
        broke_boiz = to_return.select{|ptid,result| result[:status] == 'nothing_exists' }
        if broke_boiz.count > 0
          ::CarrierPolicyType.includes(:commission_strategy).references(:commission_strategies).where(carrier_id: carrier.id, policy_type_id: broke_boiz.keys).each do |cpt|
            broke_boiz[cpt.policy_type_id][:status] = 'carrier_policy_type_exists'
            broke_boiz[cpt.policy_type_id][:commission_max] = cpt.commission_strategy&.percentage
            broke_boiz[cpt.policy_type_id][:commission_min] = 0
          end
        end
        # all done
        render json: { carrier_agency_id: carrier_agency&.id, policy_type_info: to_return },
          status: :ok
      end

      private

      def set_carrier_agency
        @carrier_agency = !params[:id].blank? ? CarrierAgency.find(params[:id]) : CarrierAgency.where(carrier_id: params[:carrier_id], agency_id: params[:agency_id]).take
      end
      
      def parent_info_params
        params.permit(
          :carrier_id,
          :agency_id,
          policy_type_ids: []
        )
      end

      def create_params
        params.require(:carrier_agency).permit(
          :carrier_id,
          :agency_id,
          :external_carrier_id,
          # commented out for now because they are automatically created by callback in the model at the moment, without checks for whether the user has manually supplied them
          #carrier_agency_authorizations_attributes: %i[state available policy_type_id zip_code_blacklist],
          carrier_agency_policy_types_attributes: [
            :policy_type_id,
            commission_strategy_attributes: [
              :percentage
            ]
          ]
        )
      end

      def update_params
        to_return = params.require(:carrier_agency).permit(
          :carrier_id, :agency_id, :external_carrier_id,
          carrier_agency_authorizations_attributes: %i[id _destroy state available policy_type_id zip_code_blacklist],
          carrier_agency_policy_types_attributes: [
            :id,
            :_destroy,
            :policy_type_id,
            commission_strategy_attributes: [
              :percentage
            ]
          ]
        )

        existed_ids = to_return[:carrier_agency_authorizations_attributes]&.map { |cpt| cpt[:id] }

        unless @carrier_agency.blank? || existed_ids.nil?
          (@carrier_agency.carrier_agency_authorizations.pluck(:id) - existed_ids).each do |id|
            to_return[:carrier_agency_authorizations_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          carrier_id: %i[scalar array],
          agency_id: %i[scalar array],
          created_at: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
