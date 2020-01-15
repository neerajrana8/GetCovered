module Reports
  class Activity < ActiveInteraction::Base
    def execute
      Agency.where(enabled: true).map do |agency|
        agency.reports.create(format: 'activity', data: prepare_agency_report(agency))
      end
    end

    private

    def prepare_agency_report(agency)
      empty_result = {
        total_policy: 0,
        total_canceled: 0,
        total_third_party: 0
      }

      agency_communities(agency).each_with_object(empty_result) do |insurable, result|
        coverage_report = insurable.coverage_report
        result[:total_policy] += coverage_report[:policy_covered_count]
        result[:total_third_party] += coverage_report[:policy_external_covered_count]
        result[:total_canceled] += coverage_report[:cancelled_policy_count]
      end
    end

    def agency_communities(agency)
      agency.insurables.where(insurable_type: InsurableType.communities)
    end
  end
end
