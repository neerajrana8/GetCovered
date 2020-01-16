module V2
  module StaffSuperAdmin
    class AssignmentsController < StaffSuperAdminController
      
      before_action :set_assignment, only: %i[show]

      def index
        super(:@assignments, Assignment.communities)
      end

      def show; end

      private

      def view_path
        super + '/assignments'
      end
                
      def set_assignment
        @assignment = Assignment.communities.find_by(id: params[:id])
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
