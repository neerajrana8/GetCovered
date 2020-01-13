module V2
  module StaffSuperAdmin
    class AssignmentsController < StaffSuperAdminController
      before_action :set_assignment, only: [:show]

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
    end
  end
end
