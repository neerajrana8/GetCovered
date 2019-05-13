# V1 Account Notifications Controller
#
# file: app/controllers/v1/account/notifications_controller.rb

module V1
  module Account
    class NotificationsController < StaffController
      
      before_action :set_notification,
        except: :index
      
      def index
	      return_all = params[:return_all].nil? ? false : params[:return_all]
	      @notifications = return_all ? current_staff.notifications : 
	      															current_staff.notifications.push.delivered
      end
      
      def show
      end
      
      def update
        if @notification.update(notification_params)   
          render :show, status: :ok
        else
          render json: @notification.errors,
            status: :unprocessable_entity
        end
      end
      
      private
        
        def set_notification
          
          return_error = true
          
          if Notification.exists?(params[:id])
            @notification = current_staff.notifications.find(params[:id])
            if !@notification.nil? && 
                @notification.notifiable == current_staff
              
              return_error = false
            end  
          end
        
          if return_error == true
            render json: { error: "Unathorized Access Attempt" }, 
                   status: 401
          end
        end

        def notification_params
          params.require(:notification).permit(:status)
        end
        
    end
  end
end
