module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # if reportable is nil generates reports for all agencies and accounts
    # in other cases it generate report for object that has two required methods or relations : reports and  insurables
    class CancelledPoliciesCreate < ActiveInteraction::Base

      def execute
        Agency.where(enabled: true).each do |agency|
          prepare_agency_report(agency)
        end
      end

      private

      def prepare_agency_report(agency)
        report = Reports::DetailedRentersInsurance::CancelledPolicies.create(reportable: agency)

        agency.accounts.each do |account|
          report.data['rows'] += prepare_account_report(account).data['rows']
        end

        report.tap(&:save)
      end

      def prepare_account_report(account)
        report = Reports::DetailedRentersInsurance::CancelledPolicies.create(reportable: account)

        account.insurables.communities.each do |insurable|
          report.data['rows'] += prepare_community_report(insurable).data['rows']
        end

        report.tap(&:save)
      end

      def prepare_community_report(insurable_community)
        Reports::DetailedRentersInsurance::CancelledPolicies.
          new(reportable: insurable_community).
          generate.
          tap(&:save)
      end
    end
  end
end
