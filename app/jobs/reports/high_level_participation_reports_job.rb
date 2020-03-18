module Reports
  class HighLevelParticipationReports < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::HighLevelParticipationCreate.run!
    end
  end
end
