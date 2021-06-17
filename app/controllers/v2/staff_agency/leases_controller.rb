##
# V2 StaffAgency Leases Controller
# File: app/controllers/v2/staff_agency/leases_controller.rb

module V2
  module StaffAgency
    class LeasesController < StaffAgencyController

      before_action :set_lease, only: [:update, :destroy, :show]
      before_action :set_substrate, only: [:create, :index]
      before_action :parse_input_file, only: %i[bulk_create]

      def index
        if params[:short]
          super(:@leases, @substrate)
        else
          super(:@leases, @substrate, :account, :insurable, :lease_type)
        end
      end

      def show
      end

      def create
        if create_allowed?
          @lease = @substrate.new(create_params)
          if !@lease.errors.any? && @lease.save_as(current_staff)
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

      def bulk_create
        account = @agency.accounts.find_by_id(bulk_create_params[:account_id])

        unless account.present?
          render json: { success: false, errors: ['account_id should be present and relate to this agency'] },
                 status: :unprocessable_entity
          return
        end

        @parsed_input_file.each do |lease_params|
          lease = Lease.create(lease_params[:lease].merge(account: account))

          if lease.valid?
            lease_params[:lease_users].each do |lease_user|
              if ::User.where(email: lease_user[:user_attributes][:email]).exists?
                user = ::User.find_by_email(lease_user[:user_attributes][:email])
                lease.users << user
              else
                secure_tmp_password = SecureRandom.base64(12)
                user = User.create(
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

      def parse_input_file
        if params[:input_file].present? && params[:input_file].content_type == 'text/csv'
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

      def bulk_create_params
        params.require(:leases).permit(
          :community_insurable_id,
          :account_id
        )
      end

      def view_path
        super + "/leases"
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

      def create_params
        return({}) if params[:lease].blank?
        params.require(:lease).permit(
          :account_id, :covered, :start_date, :end_date, :insurable_id,
          :lease_type_id, :status,
          lease_users_attributes: [:user_id],
          users_attributes: [:id, :email, :password]
        )
      end

      def update_params
        return({}) if params[:lease].blank?
        params.require(:lease).permit(
          :covered, :end_date, :start_date, :status,
          lease_users_attributes: [:user_id],
          users_attributes: [:id, :email, :password]
        )
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: [:scalar, :array],
          start_date: [:scalar, :array, :interval],
          end_date: [:scalar, :array, :interval],
          lease_type_id: [:scalar, :array],
          status: [:scalar, :array],
          covered: [:scalar],
          insurable_id: [:scalar, :array],
          account_id: [:scalar, :array]
        }
      end

      def supported_orders
        supported_filters(true)
      end

    end
  end # module StaffAgency
end
