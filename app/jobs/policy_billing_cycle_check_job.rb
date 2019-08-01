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
        UserCoverageMailer.with(user: policy.user, 
                                policy: policy).auto_pay_fail  
      end
    end
  end
  
  private
    
    def set_policies
      @policies = Policy.in_system?(true)
                        .QUOTE_ACCEPTED
                        .where(next_payment_date: Time.current.to_date - 1.days)
    end
end
