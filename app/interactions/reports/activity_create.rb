module Reports
  # Active Policies Report for Cambridge
  # if reportable is nil generates reports for all agencies and accounts
  # in other cases it generate report for object that has two required methods or relations : reports and  insurables
  class ActivityCreate < ActiveInteraction::Base
    interface :reportable, methods: %i[reports insurables]

    def execute
      data
    end

    private

    def prepare_agencies_reports
      Agency.where(enabled: true).each do |agency|
        prepare_agency_report(agency)
      end
    end

    def prepare_agency_report(agency)
      data = {
        'total_policy' => 0,
        'total_canceled' => 0,
        'total_third_party' => 0
      }

      agency.accounts.each do |account|
        account_report = prepare_report(account)
        data.keys.each { |key| data[key] += account_report.data[key] }
      end

      Reports::Activity.create(data: data, reportable: agency)
    end

    def prepare_report(reportable)
      data = {
        'total_policy' => 0,
        'total_canceled' => 0,
        'total_third_party' => 0
      }

      reportable.insurables.communities.each do |insurable|
        coverage_report = insurable.coverage_report
        data['total_policy'] += coverage_report[:policy_covered_count]
        data['total_third_party'] += coverage_report[:policy_external_covered_count]
        data['total_canceled'] += coverage_report[:cancelled_policy_count]
      end

      Reports::Activity.create(data: data, reportable: reportable)
    end
  end
end
