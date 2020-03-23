module Reports
  class HighLevelParticipationReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::HighLevelParticipationCreate.run!
    end
  end
end
