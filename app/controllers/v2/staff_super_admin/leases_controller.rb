##
# V2 StaffAgency Leases Controller
# File: app/controllers/v2/staff_agency/leases_controller.rb

module V2
  module StaffSuperAdmin
    class LeasesController < StaffSuperAdminController
      
      before_action :set_lease, only: %i[update destroy show]
            
      def index
        if params[:short]
          super(:@leases, Lease)
        else
          super(:@leases, Lease, :account, :insurable, :lease_type)
        end
      end
      
      def show; end
      
      def create
        if create_allowed?
          @lease = Lease.new(create_params)
          if @lease.errors.none? && @lease.save_as(current_staff)

            user_params[:users]&.each do |user_params|
              user = ::User.find_by(id: user_params[:id]) || ::User.find_by(email: user_params[:email])
              if user.nil?
                user = ::User.new(user_params)
                user.password = SecureRandom.base64(12)
                user.invite! if user.save
              end
              @lease.users << user
            end

            render :show, status: :created
          else
            render json: @lease.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @lease.update_as(current_staff, update_params)
            user_params[:users]&.each do |user_params|
              user = ::User.find_by(email: user_params[:email])
              if user.nil?
                user = ::User.new(user_params)
                user.password = SecureRandom.base64(12)
                user.invite! if user.save
              else
                user.update_attributes(user_params)
              end
              @lease.users << user unless @lease.users.include?(user)
            end
            
            render :show, status: :ok
          else
            render json: @lease.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @lease.destroy
            render json: { success: true },
                   status: :ok
          else
            render json: { success: false },
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      
      private

      def user_params
        params.permit(users: [:id, :email, :agency_id, profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name salutation],
                                                  address_attributes: %i[city country county state street_name street_two zip_code]])
      end
      
      def view_path
        super + '/leases'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def destroy_allowed?
        true
      end
        
      def set_lease
        @lease = Lease.find(params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lease)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.leases
        end
      end
        
      def create_params
        return({}) if params[:lease].blank?

        params.require(:lease).permit(
          :account_id, :covered, :start_date, :end_date, :insurable_id,
          :lease_type_id, :status,
          lease_users_attributes: [:user_id],
          users_attributes: %i[id email password]
        )
      end
        
      def update_params
        return({}) if params[:lease].blank?

        params.require(:lease).permit(
          :covered, :end_date, :start_date, :status,
          lease_users_attributes: [:user_id],
          users_attributes: %i[id email password]
        )
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          start_date: %i[scalar array interval],
          end_date: %i[scalar array interval],
          lease_type_id: %i[scalar array],
          status: %i[scalar array],
          covered: [:scalar],
          insurable_id: %i[scalar array],
          account_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAgency
end
