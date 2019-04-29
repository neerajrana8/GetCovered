# V1 User Carriers Controller
# file: app/controllers/v1/user/carriers_controller.rb

module V1
  module User
    class CarriersController < UserController
      before_action :set_carrier, only: :show

      def index
        super(:@carriers, Carrier)
      end

      def show
      end

      private

        def view_path
          super + '/carriers'
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            title: [:scalar, :like],
            provides_residential: [:scalar],
            provides_commercial: [:scalar],
            provides_life: [:scalar]
          }
        end

        def set_carrier
          @carrier = Carrier.find(params[:id])
        end
    end
  end
end
