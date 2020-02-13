module Reports
  class Activity < ::Report
    def to_csv
      CSV.generate do |csv|
        fields.each do |field|
          csv << [field, self.data[field]]
        end
      end
    end

    # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
    # I planned to make reports "class agnostic".
    def generate
      if reportable.is_a?(Insurable)
        coverage_report = reportable.coverage_report
        self.data['total_policy'] = coverage_report[:policy_covered_count]
        self.data['total_third_party'] = coverage_report[:policy_external_covered_count]
        self.data['total_canceled'] = coverage_report[:cancelled_policy_count]
      else
        reportable.insurables.communities.each do |insurable|
          coverage_report = insurable.coverage_report
          self.data['total_policy'] += coverage_report[:policy_covered_count]
          self.data['total_third_party'] += coverage_report[:policy_external_covered_count]
          self.data['total_canceled'] += coverage_report[:cancelled_policy_count]
        end
      end

      self
    end

    def fields
      %w[total_policy total_canceled total_third_party]
    end

    private

    def set_defaults
      self.data ||= {}
      self.data['total_policy'] ||= 0
      self.data['total_third_party'] ||= 0
      self.data['total_canceled'] ||= 0
    end
  end
end
