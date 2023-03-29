


module V2
  module StaffReporting
    class UtilitiesController < StaffReportingController
    
      def auth_check
        render json: { success: true },
          status: :ok
      end
      
    end
  end
end
