#TODO: not all methods implemented need to finish
class UserCoverageMailerPreview < ActionMailer::Preview

  def acceptance_email
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    UserCoverageMailer.with(policy: policy, user: policy.primary_user).acceptance_email

  end

  def added_to_policy
    client_host_link =
        BrandingProfiles::FindByObject.run!(object: PolicyUser.last)&.url ||
            Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]

      links = {
          accept: "#{client_host_link}/confirm-policy",
          dispute: "#{client_host_link}/dispute-policy"
      }
    policy = Policy.where(policy_type_id: 1, carrier_id: 1).last

    UserCoverageMailer.with(policy: policy, user: policy.primary_user, links: links).added_to_policy
  end

  def all_documents
    #policy = Policy.where(status: "EXTERNAL_VERIFIED").last
    policy = Policy.find(2484)
    UserCoverageMailer.with(policy: policy, user: policy.primary_user).all_documents
  end

  def auto_pay_fail
    policy = Policy.where(status: "EXTERNAL_VERIFIED").last
    UserCoverageMailer.with(user: policy.primary_user,
                            policy: policy).auto_pay_fail
  end

  def commercial_quote
    quote = Policy.find(2484).policy_quotes.last
    pu = quote.policy_application.policy_users.first
    UserCoverageMailer.with(quote: quote, user: pu.user).commercial_quote
  end

  def coverage_required
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first

    UserCoverageMailer.with(user: policy.primary_user, policy: policy).coverage_required
  end

  def coverage_required_follow_up
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    UserCoverageMailer.with(user: policy.primary_user, policy: policy).coverage_required_follow_up
  end

  def late_payment
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    UserCoverageMailer.with(user: policy.primary_user, policy: policy).late_payment
  end

  def late_payment_cancellation
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    UserCoverageMailer.with(user: policy.primary_user,
                            policy: policy).late_payment_cancellation
  end

  def payment_expiring
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    UserCoverageMailer.with(user: policy.primary_user,
                            policy: policy).payment_expiring
  end

  def policy_in_default
    policy = Policy.find(2484)
    UserCoverageMailer.with(user: policy.primary_user,
                            policy: policy).policy_in_default
  end

  def policy_expiring
    policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    UserCoverageMailer.with(user: policy.primary_user,
                            policy: policy).policy_expiring
  end

  def proof_of_coverage
    #policy = Policy.where(policy_type_id: 1, carrier_id: 1).last
    #policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    policy = Policy.find(2484)
    UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage
  end

  def qbe_proof_of_coverage
    #policy = Policy.where(status: "EXTERNAL_VERIFIED").first
    policy = Policy.find(2484)
    UserCoverageMailer.with(user: policy.primary_user, policy: policy).qbe_proof_of_coverage
  end
end
