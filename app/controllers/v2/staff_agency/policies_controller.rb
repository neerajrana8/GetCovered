##
# V2 StaffAgency Policies Controller
# File: app/controllers/v2/staff_agency/policies_controller.rb

module V2
  module StaffAgency
    class PoliciesController < StaffAgencyController
      
      before_action :set_policy, only: %i[update show]
      
      before_action :set_substrate, only: [:create, :index, :add_coverage_proof]
      
      def index
        if current_staff.getcovered_agent? && params[:agency_id].nil?
          super(:@policies, Policy.all)
        else
          super(:@policies, Policy.where(agency: @agency))
        end
      end

      def search
        @policies =
          if current_staff.getcovered_agent? && params[:agency_id].nil?
            Policy.search(params[:query]).records
          else
            Policy.search(params[:query]).records.where(agency_id: @agency)
          end
        render json: @policies.to_json, status: 200
      end
      
      def show; end
      
      def create
        if create_allowed?
          @policy = @substrate.new(create_params)
          if @policy.errors.none? && @policy.save_as(current_staff)
            render :show, status: :created
          else
            render json: @policy.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: 'Documents were sent' }
      end
      
      def update
        if update_allowed?
          if @policy.update_as(current_staff, update_params)
            render :show, status: :ok
          else
            render json: @policy.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def add_coverage_proof
        @policy = @substrate.new(coverage_proof_params)
        @policy.policy_in_system = false
        if @policy.save
          user_params[:users]&.each do |user_params|
            user = ::User.find_by(email: user_params[:email])
            if user.nil?
              user = ::User.new(user_params)
              user.password = SecureRandom.base64(12)
              if user.save
                user.invite!
              end
            end
            @policy.users << user
          end

          render json: { message: 'Policy created' }, status: :created
        else
          render json: { message: 'Policy failed' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def view_path
        super + '/policies'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def set_policy
        @policy =
          if current_staff.getcovered_agent? && params[:agency_id].nil?
            Policy.find(params[:id])
          else
            @agency.policies.find(params[:id])
          end
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Policy)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.policies
        end
      end
        
      def coverage_proof_params
        params.require(:policy).permit(:number,
          :account_id, :agency_id, :policy_type_id,
          :carrier_id, :effective_date, :expiration_date,
          :out_of_system_carrier_title, :address, documents: [],
          policy_users_attributes: [ :user_id ]
        )
      end
      
      def user_params
        params.permit(users: [:primary,
          :email, :agency_id, profile_attributes: [:birth_date, :contact_phone, 
            :first_name, :gender, :job_title, :last_name, :salutation],
          address_attributes: [ :city, :country, :state, :street_name, 
            :street_two, :zip_code] ]
        )
      end

      def create_params
        return({}) if params[:policy].blank?

        to_return = params.require(:policy).permit(
          :account_id, :agency_id, :auto_renew, :cancellation_reason,
          :cancellation_date, :carrier_id, :effective_date,
          :expiration_date, :number, :policy_type_id, :status,
          policy_insurables_attributes: [:insurable_id],
          policy_users_attributes: [:user_id],
          policy_coverages_attributes: %i[id policy_application_id policy_id
                                          limit deductible enabled designation]
        )
        to_return
      end
        
      def update_params
        return({}) if params[:policy].blank?

        params.require(:policy).permit(
          :account_id, :agency_id, :auto_renew, :cancellation_reason,
          :cancellation_date, :carrier_id, :effective_date,
          :expiration_date, :number, :policy_type_id, :status,
          policy_insurables_attributes: [:insurable_id],
          policy_users_attributes: [:user_id],
          policy_coverages_attributes: %i[id policy_application_id policy_id
                                          limit deductible enabled designation]
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
          number: %i[scalar like],
          policy_type_id: %i[scalar array],
          created_at: %i[scalar like],
          updated_at: %i[scalar like],
          status: %i[scalar like],
          policy_in_system: %i[scalar like],
          effective_date: %i[scalar like],
          expiration_date: %i[scalar like]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
