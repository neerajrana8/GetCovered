module Reports
  class Activity < ::Report
    def to_csv
      CSV.generate do |csv|
        fields.each do |field|
          csv << [field, self.data[field]]
        end
      end
    end

    private

    def fields
      %w[total_policy total_canceled total_third_party]
    end
  end
end
