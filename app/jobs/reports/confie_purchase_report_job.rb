module Reports
  class ConfiePurchaseReportJob < ApplicationJob
    queue_as :default

    def perform(policy)
      policy.inform_confie_of_policy
    end
    
  end
end
