##
# V2 StaffAccount Notifications Controller
# File: app/controllers/v2/staff_account/notifications_controller.rb

module V2
  module StaffAccount
    class NotificationsController < StaffAccountController
      
      before_action :set_notification,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@notifications, @substrate)
        else
          super(:@notifications, @substrate)
        end
      end
      
      def show
      end
      
      def update
        if update_allowed?
          if @notification.update(update_params)
            render :show,
              status: :ok
          else
            render json: @notification.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/notifications"
        end
        
        def update_allowed?
          true
        end
        
        def set_notification
          @notification = access_model(::Notification, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Notification)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.notifications
          end
        end
        
        def update_params
          return({}) if params[:notification].blank?
          params.require(:notification).permit(
            :status
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
  end # module StaffAccount
end
