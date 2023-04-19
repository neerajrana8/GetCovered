module Reports
  class GenerateChargePushReportJob < ApplicationJob
    queue_as :default

    def perform(report_id)
      report = ChargePushReport.find_by(id: report_id).generate.save
    end
  end
end
