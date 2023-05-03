class PolicyReportSyncJob < ApplicationJob
  queue_as :default

  def perform(account_or_account_id_or_all = :all)
    if account_or_account_id_or_all == :all
      ::Account.where(reporting_coverage_reports_generate: true).order(id: :asc).pluck(:id).each do |account_id|
        PolicyReportSyncJob.perform_later(account_id)
      end
      return
    end
    account = case account_or_account_id_or_all
      when ::Account
        account_or_account_id_or_all
      when ::Integer
        Account.find(account_or_account_id_or_all)
      else
        nil
    end
    Reporting::PolicyEntry.sync(account) unless account.nil?
  end

end
