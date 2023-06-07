module Reports
  class TheMikeJonesReportJob < ApplicationJob
    queue_as :default

    def perform(*)
      reports = Array.new

      # Set Up a Dates Object for use in generating and naming reports
      dates = { :base => DateTime.current - 10.days }
      dates[:last_month_start] = dates[:base].at_beginning_of_month
      dates[:last_month_end] = dates[:base].at_end_of_month
      dates[:range] = dates[:last_month_start]..dates[:last_month_end]
      dates[:report] = DateTime.current

      total_report_data = Reporting::TheMikeJones.call(nil, { :all => true })
      total_report = { :name => "internal-policies-#{ dates[:report].strftime('%Y%m%d%H%I%S') }.all.csv" }
      total_report[:data] = Utilities::CsvGenerator.call(total_report[:name], "/tmp/reports/the-mike-jones/", total_report_data)
      reports << total_report

      last_month_report_data = Reporting::TheMikeJones.call(dates[:range], {})
      last_month_report = { :name => "internal-policies-#{ dates[:report].strftime('%Y%m%d%H%I%S') }.#{ dates[:last_month_start].strftime('%B-%Y').downcase }.csv" }
      last_month_report[:data] = Utilities::CsvGenerator.call(last_month_report[:name], "/tmp/reports/the-mike-jones/", last_month_report_data)
      reports << last_month_report

      Reporting::TheMikeJonesMailer.monthly_visitor(reports).deliver_now
    end
  end
end
