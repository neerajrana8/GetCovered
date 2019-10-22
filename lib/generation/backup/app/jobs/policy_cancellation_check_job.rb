##
# Policy Canellation Check Job

class PolicyCancellationCheckJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default

  before_perform :set_policies
 
  ##
  # PolicyCancellationCheckJob.perform
  #
  # Cancels policies who do not have a complete
  # payment within the policy's carrier's 
  # grace period
  def perform(*args)
    @policies.each do |policy|
      
      days_elapsed = Integer(Time.current.to_date - policy.billing_behind_since)
      grace_period = Integer(policy.carrier.settings["late_payment_grace_period"])
      
      if days_elapsed > grace_period
        policy.cancel 
        UserCoverageMailer.with(user: policy.user, 
                                policy: policy).late_payment_cancellation
      end
      
    end
  end

  private

    def set_policies
      @policies = Policy.in_system?(true).unpaid
    end
end
