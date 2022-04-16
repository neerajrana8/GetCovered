class CardInfoUpdateMailerPreview < ActionMailer::Preview
  def please_update_card_info
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    CardInfoUpdateMailer.please_update_card_info(user: policy.primary_user, policy: policy)

  end
end
