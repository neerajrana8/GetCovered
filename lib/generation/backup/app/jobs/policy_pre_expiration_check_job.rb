##
# Policy Pre-Expiration Check Job

class PolicyPreExpirationCheckJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default
  
  before_perform :set_policies
 
  ##
  # PolicyExpirationCheckJob.perform
  #
  # Generates agent policy report mailers for agent
  # with daily notifications enabled
  def perform
    @policies.each do |policy|
      UserCoverageMailer.with(user: policy.user).policy_expiring
    end
  end
  
  private
    
    def set_policies
      @policies = Policy.in_system?(true).accepted.where(expiration_date: Time.current.to_date + 30.days)
    end
end
