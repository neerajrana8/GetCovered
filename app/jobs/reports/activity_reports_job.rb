module Reports
  class ActivityReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::ActivityCreate.run!
    end
  end
end
