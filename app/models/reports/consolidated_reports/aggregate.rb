module Reports
  module ConsolidatedReports
    class Aggregate < ::Report
      NAME = 'Weekly Agency Report - Aggregate'.freeze

      def generate(reports)
        self
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end
    end
  end
end
