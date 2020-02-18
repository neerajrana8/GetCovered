module Reports
  module DetailedRentersInsurance
    class UncoveredUnits < ::Report
      # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
      # I planned to make reports "class agnostic".
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
