module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # if reportable is nil generates reports for all agencies and accounts
    # in other cases it generate report for object that has two required methods or relations : reports and  insurables
    class UncoveredUnits < ActiveInteraction::Base
      interface :reportable, methods: %i[reports insurables], default: nil

      def execute
        if reportable.nil?
          prepare_agencies_reports
        else
          prepare_report(reportable)
        end
      end

      private

      def prepare_agencies_reports
        Agency.where(enabled: true).each do |agency|
          prepare_agency_report(agency)
        end
      end

      def prepare_agency_report(agency)
        data = { 'rows' => [] }

        agency.accounts.each do |account|
          account_report = prepare_report(account)
          data['rows'] += account_report.data['rows']
        end

        Report.create(format: 'detailed_renters_insurance::uncovered_units',
                      data: data,
                      reportable: agency)
      end

      def prepare_report(reportable)
        data = { 'rows' => [] }

        reportable.insurables.communities.each do |insurable|
          community_report_data = prepare_community_report(insurable)
          data['rows'] += community_report_data['rows']
        end

        Report.create(format: 'detailed_renters_insurance::uncovered_units',
                      data: data,
                      reportable: reportable)
      end

      def prepare_community_report(insurable_community)
        insurable_report_data = { 'rows' => [] }
        insurable_community.units.each do |unit|
          unless unit.covered
            insurable_report_data['rows'] << {
              address: unit.title
            }
          end
        end
        Report.create(format: 'detailed_renters_insurance::uncovered_units',
                      data: insurable_report_data,
                      reportable: insurable_community)
        insurable_report_data
      end
    end
  end
end
