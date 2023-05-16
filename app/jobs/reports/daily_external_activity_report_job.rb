require 'csv'

module Reports
  class DailyExternalActivityReportJob < ApplicationJob
    queue_as :default
    before_perform :setup_report

    def perform(*args)
      @accounts.each do |account|
        policies = Policy.where(account: account, status: @status_array, status_changed_on: @range,
                                policy_in_system: false)
        row = [
          account.title,
          policies.count == 0 ? 0 : policies.where(status: @status_array[0]).count,
          policies.count == 0 ? 0 : policies.where(status: @status_array[1]).count,
          policies.count == 0 ? 0 : policies.where(status: @status_array[2]).count,
          policies.count
        ]

        @report << row
      end

      CSV.open(Rails.root.join('tmp',@report_file_name), "w") do |csv|
        @report.each do |row|
          csv << row
        end
      end

      mailer = ActionMailer::Base.new
      mailer.attachments[@report_file_name] = File.read("tmp/#{ @report_file_name }")
      mailer.mail(from: "no-reply@getcoveredllc.com",
                  to: %w[dylan@getcovered.io brandon@getcovered.io],
                  subject: @report_file_name.gsub('-', ' ').gsub('.', ' ').titlecase,
                  body: "This content is pointless.  This email is simply a vehicle for #{ @report_file_name }").deliver
    end

    private

    def setup_report
      start = DateTime.current.at_beginning_of_day
      ending = DateTime.current.at_end_of_day
      @range = start..ending

      @accounts = Account.all
      @status_array = %w[EXTERNAL_UNVERIFIED EXTERNAL_VERIFIED EXTERNAL_REJECTED]
      @totals = Policy.where(status: @status_array, status_changed_on: @range, policy_in_system: false)

      @report_file_name = "external-policies-by-account-#{ DateTime.current.strftime('%Y-%m-%d') }.csv"

      @report = Array.new
      @report << %w[Account Unverified Verified Rejected Total]

      @report << [
        "Total",
        @totals.where(status: @status_array[0]).count,
        @totals.where(status: @status_array[1]).count,
        @totals.where(status: @status_array[2]).count,
        @totals.count
      ]
    end
  end
end
