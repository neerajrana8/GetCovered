module Reports
  class ActivePoliciesReportsJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::ActivePoliciesCreate.run!
    end
  end
end
