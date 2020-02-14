module Reports
  # Active Policies Report for Cambridge
  # if reportable is nil generates reports for all agencies and accounts
  class ActivityCreate < ActiveInteraction::Base
    def execute
      prepare_agencies_reports
    end

    private

    def prepare_agencies_reports
      Agency.where(enabled: true).each do |agency|
        prepare_agency_report(agency)
      end
    end

    # Optimization to reduce the amount of requests to the database.
    # Should return in a result the same data as for: Reports::Activity.new(reportable: account).generate or
    # Reports::Activity.new(reportable: agency)
    def prepare_agency_report(agency)
      agency_report = Reports::Activity.new(reportable: agency)

      agency.accounts.each do |account|
        account_report = prepare_account_report(account)
        agency_report.fields.each { |field| agency_report.data[field] += account_report.data[field] }
      end

      agency_report.save
    end

    def prepare_account_report(account)
      account_report = Reports::Activity.new(reportable: account)

      account.insurables.communities.each do |insurable|
        community_report = prepare_community_report(insurable)
        account_report.fields.each { |field| account_report.data[field] += community_report.data[field] }
      end

      account_report.tap(&:save)
    end

    def prepare_community_report(community)
      Reports::Activity.new(reportable: community).generate.tap(&:save)
    end
  end
end
