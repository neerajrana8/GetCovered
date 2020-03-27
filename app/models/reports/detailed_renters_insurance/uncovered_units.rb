module Reports
  module DetailedRentersInsurance
    class UncoveredUnits < ::Report
      NAME = 'Detailed Renters Insurance - Uncovered units'.freeze

      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units
          else
            reportable.insurables.units
          end

        units&.each do |unit|
          self.data['rows'] << { 'address' => unit.title } unless unit.covered
        end

        self
      end

      def headers
        %w[address]
      end

      def column_names
        { 'address' => 'Address' }
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end
    end
  end
end
