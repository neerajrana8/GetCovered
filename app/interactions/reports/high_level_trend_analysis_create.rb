module Reports
  class HighLevelTrendAnalysisCreate < ActiveInteraction::Base
    def execute
      prepare_accounts_reports
    end

    private

    def prepare_accounts_reports
      Agency.where(enabled: true).each do |agency|
        agency.accounts.each { |account| prepare_account_report(account) }
      end
    end

    def prepare_account_report(account)
      Reports::HighLevelTrendAnalysis.
        new(reportable: account).
        generate.
        save
    end
  end
end
