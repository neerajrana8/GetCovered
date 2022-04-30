class PoliciesPurchaseMailerPreview < ActionMailer::Preview
  def get_covered
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    Policies::PurchaseMailer.with(policy: policy).get_covered
  end

  def agency
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    Policies::PurchaseMailer.with(policy: policy, staff: policy.agency.staffs.take).agency
  end

  def account
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    Policies::PurchaseMailer.with(policy: policy, staff:  policy.account.staffs.take).account
  end
end
