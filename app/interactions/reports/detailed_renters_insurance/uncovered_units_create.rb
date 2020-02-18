module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # Generates reports for all agencies and accounts
    class UncoveredUnitsCreate < ActiveInteraction::Base

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
        report = Reports::DetailedRentersInsurance::UncoveredUnits.new(reportable: agency)

        agency.accounts.each do |account|
          report.data['rows'] += prepare_account_report(account).data['rows']
        end
        report.tap(&:save)
      end

      def prepare_account_report(account)
        report = Reports::DetailedRentersInsurance::UncoveredUnits.new(reportable: account)

        account.insurables.communities.each do |insurable|
          report.data['rows'] += prepare_community_report(insurable).data['rows']
        end
        report.tap(&:save)
      end

      def prepare_community_report(insurable_community)
        Reports::DetailedRentersInsurance::UncoveredUnits.
          new(reportable: insurable_community).
          generate.
          tap(&:save)
      end
    end
  end
end
