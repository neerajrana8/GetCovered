# =Policy Billing Cycle Check

class PolicyBillingCycleCheckJob < ApplicationJob
  
  # Queue: Default
  queue_as :default
  
  before_perform :set_policies
  
  # PolicyBillingCycleCheckJob.perform
  #
  # Checks for policies where next payment date
  # is today and generates payment if auto-billing
  # is enabled
  
  def perform(*args)
    @policies.each do |policy|
      if policy.auto_pay == false
        UserCoverageMailer.with(user: policy.primary_user, 
                                policy: policy).auto_pay_fail.deliver
      end
    end
  end
  
  private
    
    def set_policies
      @policies = Policy.in_system?(true).QUOTE_ACCEPTED
    end
end
