module Reports
  class DailySalesJob < ApplicationJob
    queue_as :default

    def perform(reportable_id, reportable_type, range_start, range_end)
      Reports::DailySales.
        new(
          reportable_id: reportable_id,
          reportable_type: reportable_type,
          range_start: Time.zone.at(range_start),
          range_end: Time.zone.at(range_end)
        ).
        generate.
        save
    end
  end
end
