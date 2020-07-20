class AutomaticMasterPolicyInvoiceJob < ApplicationJob
  queue_as :default

  def perform(policy_id)
    master_policy = Policy.current.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type_id != PolicyType::MASTER_ID

    MasterPolicies::GenerateNextInvoice.run!(master_policy: master_policy)
    AutomaticMasterPolicyInvoiceJob.set(wait: 1.month).perform_later(master_policy.id)
  end
end
