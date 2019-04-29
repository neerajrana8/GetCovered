# V1 User Notifications Controller
#
# file: app/controllers/v1/user/notifications_controller.rb

module V1
  module User
    class NotificationsController < UserController
      
      before_action :set_notification,
        except: :index
      
      def index
        @notifications = current_user.notifications.push.active
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
            @notification = current_user.notifications.find(params[:id])
            if !@notification.nil? && 
                @notification.notifiable == current_user
              
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