module Reports
  module DetailedRentersInsurance
    class UncoveredUnits < ::Report

      def generate
        insurable_community.units&.each do |unit|
          unless unit.covered
            data['rows'] << {
              address: unit.title
            }
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows:[] }
      end

      def headers
        %w[address]
      end
    end
  end
end
