class MasterPoliciesMailerPreview < ActionMailer::Preview
  def bill_master_policy
    master_policy = Policy.where(policy_type: PolicyType::MASTER_IDS).take
    invoice = Invoice.last
    MasterPoliciesMailer.with(master_policy: master_policy, staff: Staff.last, invoice: invoice).bill_master_policy

  end
end
