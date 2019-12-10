# Build Coverage Reports Job
# file: app/jobs/build_coverage_reports_job.rb

class BuildCoverageReportsJob < ApplicationJob

  # Queue: Default
  queue_as :default

  ##
  # AgentWeeklyPolicyReportJob.perform
  #
  # Generates agent policy report mailers for agent
  # with weekly notifications enabled
  def perform(*args)
    Reports::PrepareCoverageReport.run!
  end
end
