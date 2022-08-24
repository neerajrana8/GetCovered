##
# V2 StaffAccount Leases Controller
# File: app/controllers/v2/staff_account/leases_controller.rb

module V2
  module StaffAccount
    class LeasesController < StaffAccountController
      include LeasesMethods

      before_action :set_lease, only: %i[update destroy show]
      
      before_action :set_substrate, only: %i[create index]
      
      before_action :parse_input_file, only: %i[bulk_create]
      
      def index
        super(:@leases, current_staff.organizable.leases, :account, :insurable, :lease_type)

        render template: 'v2/shared/leases/index', status: :ok
      end

      def show
        render template: 'v2/shared/leases/show', status: :ok
      end

      def bulk_create
        @parsed_input_file.each do |lease_params|
          lease = Lease.create(lease_params[:lease].merge(account: current_staff.organizable))

          if lease.valid?
            lease_params[:lease_users].each do |lease_user|
              if ::User.where(email: lease_user[:user_attributes][:email]).exists?
                user = ::User.find_by_email(lease_user[:user_attributes][:email])
                lease.users << user
              else
                secure_tmp_password = SecureRandom.base64(12)
                user = ::User.create(
                  email: lease_user[:user_attributes][:email],
                  password: secure_tmp_password,
                  password_confirmation: secure_tmp_password,
                  profile_attributes: lease_user[:user_attributes][:profile_attributes]
                )
                if !user.valid?
                  ap user.errors.full_messages
                  render json: { success: false, message: user.errors.full_messages } && return
                else
                  lease.users << user
                end
              end
            end
            Leases::InviteUsersJob.perform_later(lease)
          else
            render json: { success: false, message: lease.errors.full_messages } && return
          end
        end
        head :no_content
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
      
      def view_path
        super + '/leases'
      end

      def destroy_allowed?
        true
      end
        
      def set_lease
        @lease = access_model(::Lease, params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lease)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.leases
        end
      end

      def parse_input_file
        if params[:input_file].present?
          file = params[:input_file].open
          result =
            ::Leases::BulkCreate::InputFileParser.run(
              input_file: file,
              insurable_id: bulk_create_params[:community_insurable_id]
            )

          unless result.valid?
            render(json: { error: 'Bad file', content: result.errors[:bad_rows] }, status: :unprocessable_entity) && return
          end

          render json: { error: 'No valid rows' }, status: :unprocessable_entity if result.result.empty?

          @parsed_input_file = result.result
        else
          render json: { error: 'Need the correct csv spreadsheet' }, status: :unprocessable_entity
        end
      end
        
      def create_params
        return({}) if params[:lease].blank?

        params.require(:lease).permit(
          :covered, :end_date, :insurable_id, :lease_type_id,
          :start_date, :status,
          lease_users_attributes: [:user_id],
          users_attributes: %i[id email password]
        )
      end

      def bulk_create_params
        params.require(:leases).permit(
          :community_insurable_id
        )
      end
        
      def update_params
        return({}) if params[:lease].blank?
        
        params.require(:lease).permit(
          :covered, :end_date, :start_date, :status, :account_id, :insurable_id,
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
          account_id: %i[scalar array],
          lease_users: {user_id: %i[scalar array]}
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAccount
end
