module Reports
  class HighLevelActivityCreate < ActiveInteraction::Base
    def execute
      prepare_agencies_reports
    end

    private

    def prepare_agencies_reports
      Agency.where(enabled: true).each do |agency|
        prepare_agency_report(agency)
      end
    end

    def prepare_agency_report(agency)
      agency.accounts.each { |account| prepare_account_report(account) }
      Reports::HighLevelActivity.
        new(reportable: agency).
        generate.
        tap(&:save)
    end

    def prepare_account_report(account)
      Reports::HighLevelActivity.
        new(reportable: account).
        generate.
        save
    end
  end
end
