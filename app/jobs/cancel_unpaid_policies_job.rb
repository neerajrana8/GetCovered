class CancelUnpaidPoliciesJob < ApplicationJob
  queue_as :default
  before_perform :set_policies

  # MOOSE WARNING: policy group stuff commented out for now because PGs introduce problems (no #cancel method, what if someone cancels an individual policy, how are we tracking unearned_premium anyway, etc.)

  def perform(*_args)
    curdate = Time.current.to_date
    @policies.each do |policy|
      policy.cancel('nonpayment', curdate)
    end
    #@policy_groups.each do |policy_group|
    #  policy_group.cancel('nonpayment', curdate)
    #end
  end

  private
  
    def set_policies
      cutoff = Time.current.to_date - 30.days
      @policies = Policy.policy_in_system(true).current.where(billing_status: 'BEHIND').where('billing_behind_since <= ?', cutoff)
      #@policy_groups = PolicyGroup.policy_in_system(true).current.where(billing_status: 'BEHIND').where('billing_behind_since <= ?', cutoff)
    end


end
