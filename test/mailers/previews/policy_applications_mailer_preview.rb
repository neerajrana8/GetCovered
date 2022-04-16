class PolicyApplicationsMailerPreview < ActionMailer::Preview
  def invite_to_pay
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    PolicyApplications::RentGuaranteeMailer.with(policy_application: policy.policy_application).invite_to_pay

  end
end
