class AutomaticMasterPolicyInvoiceJob < ApplicationJob
  queue_as :default

  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type.designation != 'MASTER'

    master_policy.master_policy_billing
    #AutomaticMasterCoveragePolicyInvoiceJob.set(wait: 1.month).perform_later(policy_id)
  end
end
