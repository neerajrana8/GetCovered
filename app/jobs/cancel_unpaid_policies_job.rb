class CancelUnpaidPoliciesJob < ApplicationJob
  queue_as :default
  before_perform :set_policies

  # MOOSE WARNING: policy group stuff commented out for now because PGs introduce problems (no #cancel method, what if someone cancels an individual policy, how are we tracking unearned_premium anyway, etc.)

  # MOOSE WARNING: commented out at miguel's request until pexrex time

  def perform(*_args)
=begin
    curdate = Time.current.to_date
    @policies.each do |policy|
      policy.cancel('nonpayment', curdate)
    end
    #@policy_groups.each do |policy_group|
    #  policy_group.cancel('nonpayment', curdate)
    #end
=end
  end

  private
  
    def set_policies
=begin
      # grab all policies that need to be cancelled due to nonpayment
      @policies = ::Policy.where(id: 0) # guaranteed to have empty result set (we just want to attach .or queries to this)
      CarrierPolicyType.all.each do |cpt|
        cutoff = Time.current.to_date - cpt.days_late_before_cancellation
        @policies = @policies.or(::Policy.where(policy_type_id: cpt.policy_type_id, carrier_id: cpt.carrier_id, billing_status: 'BEHIND').where('billing_behind_since <= ?', cutoff))
      end
      @policies = @policies.policy_in_system(true).current
      # MOOSE WARNING: @policy_group stuff???
=end
    end


end
