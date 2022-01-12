module Reports
  class DailySalesExternalSendEmailsJob < ApplicationJob
    queue_as :default

    def perform
      @range_start = Time.zone.now

      Agency.enabled.each do |agency|
        emails_for_reportable(agency)

        agency.accounts.enabled.each do |account|
          emails_for_reportable(account)
        end

        agency.agencies.enabled.each do |sub_agency|
          emails_for_reportable(sub_agency)

          sub_agency.accounts.enabled.each do |account|
            emails_for_reportable(account)
          end
        end
      end
    end

    private

    def emails_for_reportable(reportable)
      recipients =
        owner_email =
          if reportable.owner.present? && permitted?(reportable.owner, 'daily_sales_report')
            reportable.owner.profile&.contact_email || reportable.owner.email
          end
        reportable_email =
          (reportable.contact_info['contact_email'] if permitted?(reportable, 'daily_sales_report'))

        [owner_email, reportable_email].uniq.compact

      if recipients.any?
        report_path =
          Reports::DailySalesAggregate.new(range_start: @range_start, reportable: reportable).generate.generate_csv

        DailySalesReportMailer.
          send_report(recipients, report_path, reportable.title, @range_start.yesterday.to_date.to_s).deliver
      end
    end
  end
end
