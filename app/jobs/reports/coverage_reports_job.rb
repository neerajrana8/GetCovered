module Reports
  class CoverageReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::CoverageCreate.run!
    end
  end
end
