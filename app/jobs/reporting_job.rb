class ReportingJob < ApplicationJob
  queue_as :default

  def perform(account, report_time = Time.current.to_date, create_params: {})
    created = Reporting::CoverageReport.create(owner: account, report_time: report_time, **create_params)
    if created.id.nil?
      puts "Error creating report: #{created.errors.to_h}"
      return
    end
    puts "Created CoverageReport ##{created.id}; generating entries..."
    created.generate!
    puts "Generation complete!"
  end

end
