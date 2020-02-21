module Reports
  class HighLevelActivityReports < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::HighLevelActivityCreate.run!
    end
  end
end
