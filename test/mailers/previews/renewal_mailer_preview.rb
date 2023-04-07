class RenewalMailerPreview < ActionMailer::Preview
  def policy_renewing_soon
    policy = Policy.where(policy_type_id: 1, carrier_id: 1, status: 'EXPIRED').last

    RenewalMailer.with(policy: policy).policy_renewing_soon
  end

  def policy_renewal_success
    policy = Policy.where(policy_type_id: 1, carrier_id: 1, status: 'EXPIRED').last

    RenewalMailer.with(policy: policy).policy_renewal_success
  end

  def policy_renewal_failed
    policy = Policy.where(policy_type_id: 1, carrier_id: 1, status: 'EXPIRED').last

    RenewalMailer.with(policy: policy).policy_renewal_failed
  end
end


