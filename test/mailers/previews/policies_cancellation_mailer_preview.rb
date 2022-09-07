class PoliciesCancellationMailerPreview < ActionMailer::Preview
  def refund_request
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    Policies::CancellationMailer.with(policy: policy, without_request: true).refund_request
  end

  def cancel_request
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    change_request = ChangeRequest.new(requestable: policy.primary_insurable, changeable: policy, customized_action: 'cancel')
  
    Policies::CancellationMailer.with(policy: policy, change_request: change_request).cancel_request
  end

  def cancel_confirmation
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    Policies::CancellationMailer.with(policy: policy, without_request: true).cancel_confirmation
  end
end
