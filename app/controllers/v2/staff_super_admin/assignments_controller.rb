module V2
  module StaffSuperAdmin
    class AssignmentsController < StaffSuperAdminController
      before_action :set_assignment, only: %i[update destroy show]
      before_action :set_staff, :set_email_notification, only: %i[create]

      def index
        super(:@assignments, Assignment.communities)
      end

      def show; end

      # NOTE: copy from staff_account
      def create
        if create_allowed?
          @assignment = Assignment.new(create_params.except("notification_settings_attributes"))
          if @assignment.errors.none? && @assignment.save
            switch_email_notification
            render :show,
                   status: :created
          else
            render json: @assignment.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      # NOTE: copy from staff_account
      def update
        if update_allowed?
          if @assignment.update(update_params)
            render :show,
                   status: :ok
          else
            render json: @assignment.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      # NOTE: copy from staff_account
      def destroy
        if destroy_allowed?
          if @assignment.destroy
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
        super + '/assignments'
      end

      def set_assignment
        @assignment = Assignment.communities.find_by(id: params[:id])
      end

      def set_staff
        @staff = Staff.find_by(id: create_params[:staff_id])
      end

      def set_email_notification
        @email_notification = @staff.notification_settings.find_by(action: 'external_policy_emails_copy')
      end

      def switch_email_notification
        if @email_notification.blank?
          render json: { success: false, errors: ['Notification setting not updated'] },
                 status: :unprocessable_entity
        else
          @email_notification.update(enabled: create_params['notification_settings_attributes']['external_policy_emails_copy']) if create_params['notification_settings_attributes'].present?
        end
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

      def create_params
        return({}) if params[:assignment].blank?

        to_return = params.require(:assignment).permit(
          :assignable_id, :assignable_type, :primary, :staff_id,
          notification_settings_attributes: {})
        to_return
      end

      def update_params
        return({}) if params[:assignment].blank?

        params.require(:assignment).permit(
          :assignable_id, :assignable_type, :primary, :staff_id
        )
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
