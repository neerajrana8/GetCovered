class PoliciesMailerPreview < ActionMailer::Preview
  def proof_of_coverage
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    CarrierQBE::PoliciesMailer.with(user: policy.primary_user, policy: policy).proof_of_coverage
  end
end

