class PolicyQuoteStartBillingJob < ApplicationJob
  queue_as :default

  def perform(policy:, issue:)
    return if policy.nil?
    # send documents
    unless !policy.respond_to?(issue) || policy.carrier_id == 5 # MOOSE WARNING: disable for MSI for now...
      policy.send(issue)
      UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver if policy.policy_type_id != 5
      UserCoverageMailer.with(policy: policy, user: policy.primary_user).all_documents.deliver if policy.policy_type_id == 5
    end
    acct = AccountUser.find_by(user_id: policy.primary_user.id, account_id: policy.primary_user.account_users.last&.account_id)
    # enable account users
    acct.update(status: 'enabled') if acct.present? && acct.status != 'enabled'
    # invite policy users
    policy.policy_users.each(&:invite)
  end
end
