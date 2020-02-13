module Reports
  class Coverage < ::Report

    def to_csv
      CSV.generate do |csv|
        fields.each do |field|
          csv << [field, self.data[field]]
        end
      end
    end

    def generate
      self.data = reportable.coverage_report
      self
    end

    def fields
      %w[
         unit_count
         occupied_count
         covered_count
         master_policy_covered_count
         policy_covered_count
         policy_internal_covered_count
         policy_external_covered_count
         cancelled_policy_count
      ]
    end

    private
    
    def set_defaults
      self.duration ||= 'day'
      self.data ||= {}
      self.data['unit_count'] ||= 0
      self.data['occupied_count'] ||= 0
      self.data['covered_count'] ||= 0
      self.data['master_policy_covered_count'] ||= 0
      self.data['policy_covered_count'] ||= 0
      self.data['policy_internal_covered_count'] ||= 0
      self.data['policy_external_covered_count'] ||= 0
      self.data['cancelled_policy_count'] ||= 0
    end
  end
end
