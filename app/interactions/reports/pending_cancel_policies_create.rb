module Reports
  class PendingCancelPoliciesCreate < ActiveInteraction::Base
    def execute
      Agency.where(enabled: true).each do |agency|
        prepare_agency_report(agency)
      end
    end

    private

    def prepare_agency_report(agency)
      report = Reports::PendingCancelPolicies.new(reportable: agency)

      agency.accounts.each do |account|
        report.data['rows'] += prepare_account_report(account).data['rows']
      end

      report.save
    end

    def prepare_account_report(account)
      account_report = Reports::PendingCancelPolicies.new(reportable: account)

      account.insurables.communities.each do |insurable|
        account_report.data['rows'] += prepare_community_report(insurable).data['rows']
      end

      account_report.tap(&:save)
    end

    def prepare_community_report(insurable_community)
      Reports::PendingCancelPolicies.
        new(reportable: insurable_community).
        generate.
        tap(&:save)
    end
  end
end
