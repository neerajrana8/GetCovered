module Reports
  class HighLevelTrendAnalysisReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::HighLevelTrendAnalysisCreate.run!
    end
  end
end
