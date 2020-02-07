module Reports
  class RunCoverageReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::CoverageCreate.run!
    end
  end
end
