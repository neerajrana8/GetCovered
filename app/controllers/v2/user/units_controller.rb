##
# V1 User Units Controller
# file: app/controllers/v1/user/units_controller.rb

module V1
  module User
    class UnitsController < UserController
      before_action :set_unit,
        only: :show

      def index
        super(:@units, current_user.units)
      end

      def show
      end

      private

        def view_path
          super + '/units'
        end

        def supported_filters
          {
            mailing_id: [ :scalar, :array, :like ],
            type: [ :scalar, :array ],
            occupied: [ :scalar ],
            covered: [ :scalar ],
            building_id: [ :scalar, :array ]
          }
        end

        def set_unit
          @unit = current_user.units.find(params[:id])
        end
    end
  end
end
