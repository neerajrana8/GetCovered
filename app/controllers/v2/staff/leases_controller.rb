# frozen_string_literal: true

# V1 Account Leases Controller
# file: app/controllers/v1/account/leases_controller.rb

module V1
  module Staff
    class LeasesController < StaffController
      before_action :only_super_admins, only: [:destroy]
      before_action :set_lease,
                    only: %i[show update create_lease_user delete_lease_user]

      def index
        super(:@leases, @account.leases)
      end

      def show; end

      def new; end

      def create
        @lease = @account.leases.new(lease_params)
        if @lease.save_as(current_staff)
          render :show, status: :created
        else
          render json: @lease.errors,
                 status: :unprocessable_entity
        end
      end

      def update
        if @lease.update_as(current_staff, lease_params)
          render :show, status: :ok
        else
          render json: @lease.errors,
                 status: :unprocessable_entity
        end
      end

      def create_lease_user
        lease_user = @lease.lease_users.new(lease_user_params)
        if lease_user.save
          render json: { success: true }, status: :ok
        else
          render json: { success: false, errors: lease_user.errors },
                 status: :unprocessable_entity
        end
      end

      def delete_lease_user
        lease_user = @lease.lease_users.find(params[:lease_user_id])
        if lease_user.nil?
          render json: { success: false, errors: { id: 'Lease user does not exist.' } },
                 status: :unprocessable_entity
        else
          lease_user.delete
          render json: { success: true }, status: :ok
        end
      end

      private

      def view_path
        super + '/leases'
      end

      def lease_user_params
        params.require(:lease_user).permit(:lease_id, :user_id)
      end

      def lease_params
        params.require(:lease).permit(:start_date, :end_date,
                                      :type, :status, :covered,
                                      :unit_id, :reference, :account_id)
      end

      def supported_filters
        {
          id: %i[scalar array],
          start_date: %i[scalar array interval],
          end_date: %i[scalar array interval],
          type: %i[scalar array],
          status: %i[scalar array],
          covered: [:scalar],
          unit_id: %i[scalar array]
        }
      end

      def set_lease
        @lease = @account.leases.find(params[:id])
      end
    end
  end
end
