class ActivateAccountMailerPreview < ActionMailer::Preview
  def third_party_insurance
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    #policy = Policy.where(status: "EXTERNAL_VERIFIED").firs
    ActivateAccountMailer.third_party_insurance(policy: policy, user: policy.primary_user)
  end

  def master_policy_enrollment
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    #policy = Policy.where(status: "EXTERNAL_VERIFIED").firs
    ActivateAccountMailer.master_policy_enrollment(policy: policy, user: policy.primary_user)
  end

  def renters_insurance_policy_purchase
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    ActivateAccountMailer.renters_insurance_policy_purchase(policy: policy, user: policy.primary_user)
  end
end
