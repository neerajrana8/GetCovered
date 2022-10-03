class CustomDeviseMailerPreview < ActionMailer::Preview
  def invitation_instructions
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    policy.primary_user.invite!
  end

  #TODO: reset password need to be added

end
