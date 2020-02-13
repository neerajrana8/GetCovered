module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # Generates reports for all active agencies and accounts
    class PendingCancellationPoliciesCreate < ActiveInteraction::Base
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
        report = Reports::DetailedRentersInsurance::PendingCancellationPolicies.new(reportable: agency)

        agency.accounts.each do |account|
          report.data['rows'] += prepare_account_report(account).data['rows']
        end

        report.tap(&:save)
      end

      def prepare_account_report(account)
        Reports::DetailedRentersInsurance::PendingCancellationPolicies.
          new(reportable: account).
          generate.
          tap(&:save)
      end
    end
  end
end
