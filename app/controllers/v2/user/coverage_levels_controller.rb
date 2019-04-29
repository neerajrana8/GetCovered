##
# V1 User Coverage Levels Controller
# file: app/controllers/v1/user/coverage_levels_controller.rb

module V1
  module User
    class CoverageLevelsController < UserController
      before_action :set_carrier
      before_action :set_coverage_level,
        only: :show

      def index
        super(:@coverage_levels, @carrier.coverage_levels)
      end

      def show
      end

      private

        def view_path
          super + '/coverage_levels'
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            enabled: [:scalar],
            coverage_type: [:scalar, :array],
            coverage_liability: [:scalar, :array, :interval],
            coverage_possesions: [:scalar, :array, :interval],
            coverage_medical: [:scalar, :array, :interval],
            coverage_deductible: [:scalar, :array, :interval],
            additional_insured_rate: [:scalar, :array, :interval],
            coverage_zipcodes: [:scalar, :array],
            carrier_id: [:scalar, :array],
            community_id: [:scalar, :array]
          }
        end

        def set_carrier
          @carrier = Carrier.find(params[:carrier_id])
        end

        def set_coverage_level
          @coverage_level = @carrier.coverage_levels.find(params[:id])
        end
    end
  end
end
