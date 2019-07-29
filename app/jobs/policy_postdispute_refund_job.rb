##
# Policy Postdispute Refund Job

class PolicyPostdisputeRefundJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default
  
  before_perform :set_policies
 
  ##
  # PolicyPostdisputeRefundJob.perform
  #
  # Performs queued refunds after all disputes are resolved on a policy.
  def perform
    @policies.each do |policy|
      policy.perform_postdispute_processing
    end
  end
  
  private
    
    def set_policies
      @policies = Policy.in_system?(true).awaiting_postdispute_processing
    end
end
