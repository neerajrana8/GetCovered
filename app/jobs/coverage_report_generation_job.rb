class CoverageReportGenerationJob < ApplicationJob
  queue_as :default

  def perform(account_report_or_all = :all, report_time = Time.current, create_params: {})
    case account_report_or_all
      when :all # generate all reports
        Reporting::CoverageReport.generate_all!(report_time)
      when Reporting::CoverageReport # regenerate a particular report (doesn't use report_time)
        account_report_or_all.generate! unless account_report_or_all.status == 'ready'
      when ::Account, nil # generate a single report
        account = account_report_or_all
        created = Reporting::CoverageReport.create(owner: account, report_time: report_time, **create_params)
        if created.id.nil?
          puts "Error creating report: #{created.errors.to_h}"
          return
        end
        puts "Created CoverageReport ##{created.id}; generating entries..."
        result = created.generate!
        if result.nil?
          puts "Generation complete!"
        else
          puts "Generation failed: #{result[:class]}: #{result[:message]}"
        end
      else
        raise StandardError.new("Invalid account_report_or_all parameter passed: #{account_report_or_all}")
    end
  end

end
