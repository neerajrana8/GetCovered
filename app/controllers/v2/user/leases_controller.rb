##
# V1 User Leases Controller
# file: app/controllers/v1/user/leases_controller.rb

module V2
  module User
    class LeasesController < UserController
      before_action :set_lease,
        only: :show

      def index
        super(:@leases, current_user.leases)
      end

      def show
      end

      private

        def view_path
          super + '/leases'
        end

        def supported_filters
          {
            start_date: [ :scalar, :array, :interval ],
            end_date: [ :scalar, :array, :interval ],
            type: [ :scalar, :array ],
            status: [ :scalar, :array ],
            covered: [ :scalar ],
            unit_id: [ :scalar, :array ]
          }
        end

        def set_lease
          @lease = current_user.leases.find(params[:id])
        end
    end
  end
end
