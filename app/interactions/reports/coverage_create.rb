module Reports
  class CoverageCreate < ActiveInteraction::Base
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
      Reports::Coverage.
        new(reportable: agency).
        generate.
        save
    end

    def prepare_account_report(account)
      account.insurables.communities.each{ |insurable| prepare_insurable_report(insurable) }
      Reports::Coverage.
        new(reportable: account).
        generate.
        save
    end

    def prepare_insurable_report(insurable)
      Reports::Coverage.
        new(reportable: insurable).
        generate.
        save
    end
  end
end
