module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # Generates reports for all enabled agencies and accounts
    class ActivePoliciesCreate < ActiveInteraction::Base

      def execute
        Agency.where(enabled: true).each do |agency|
          prepare_agency_report(agency)
        end
      end

      private

      def prepare_agency_report(agency)
        report = Reports::DetailedRentersInsurance::ActivePolicies.new(reportable: agency)

        agency.accounts.each do |account|
          report.data['rows'] += prepare_account_report(account).data['rows']
        end

        report.save
      end

      def prepare_account_report(account)
        Reports::DetailedRentersInsurance::ActivePolicies.
          new(reportable: account).
          generate.
          tap(&:save)
      end
    end
  end
end
