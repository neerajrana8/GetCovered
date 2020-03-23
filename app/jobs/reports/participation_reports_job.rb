module Reports
  class ParticipationReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::ParticipationCreate.run!
    end
  end
end
