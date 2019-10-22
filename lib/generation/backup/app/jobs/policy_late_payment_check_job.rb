##
# Policy Late Payment Check Job

class PolicyLatePaymentCheckJob < ApplicationJob
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
  def perform      
    @policies.each do |policy|
      policy.update billing_status: 'behind',
                    billing_behind_since: Time.current.to_date
      
      UserCoverageMailer.with(user: policy.user, policy: policy).late_payment 
    end
  end

  private

    def set_policies
      yesterday = (Time.current - 1.days).to_date
      @policies = Policy.in_system?(true).where(next_payment_date: yesterday)
    end
end
