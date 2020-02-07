module Reports
  class CoverageCreate < ActiveInteraction::Base
    def execute
      agencies.each do |agency|

        # set up new coverage report for agency
        agency_report = Reports::Coverage.new(reportable: agency)

        # loop through accounts from agency
        agency.accounts.each do |account|

          # set up new coverage report for account
          account_report = Reports::Coverage.new(reportable: account)

          # loop through account insurables
          account.insurables.where(insurable_type_id: InsurableType.communities.ids).each do |insurable|
            # set up new coverage report for insurable
            insurable_report = Reports::Coverage.new(reportable: insurable, data: insurable.coverage_report)

            # save Unit Report
            if insurable_report.save
              insurable_report.data.each do |key, value|
                insurable_report.data[key] += value
                account_report.data[key] += value
                agency_report.data[key] += value
              end
            else
              logger.debug insurable_report.errors.to_json
            end
          end

          # save account report and generate staff reports from insurable reports
          unless account_report.save
            logger.debug account_report.errors.to_json
          end
        end

        unless agency_report.save
          logger.debug "\n[ BuildCoverageReportsJob ]: Failure Saving Agency Report. #{agency_report.errors.to_json}"
        end
      end
    end

    private

    def agencies
      Agency.where(enabled: true)
    end
  end
end
