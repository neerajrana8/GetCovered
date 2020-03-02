module Reports
  class RenewalPoliciesCreateJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Reports::RenewalPoliciesCreate.run!
    end
  end
end
