##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController
      
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
          @lease = @substrate.new(create_params)
          if !@lease.errors.any? && @lease.save
            render :show,
              status: :created
          else
            render json: @lease.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @lease.update(update_params)
            render :show,
              status: :ok
          else
            render json: @lease.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      private
        
        def create_params
          return({}) if params[:lease].blank?
          params.require(:lease).permit(
            :account_id, :covered, :start_date, :end_date, :insurable_id,
            :lease_type_id, :status,
            lease_users_attributes: [ :user_id ],
            users_attributes: [ :id, :email, :password ]
          )
        end
        
        def update_params
          return({}) if params[:lease].blank?
          params.require(:lease).permit(
            :covered, :end_date, :start_date, :status,
            lease_users_attributes: [ :user_id ],
            users_attributes: [ :id, :email, :password ]
          )
        end
    end
  end # module StaffAgency
end
