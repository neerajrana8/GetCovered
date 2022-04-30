class PolicyQuoteStartBillingJob < ApplicationJob
  queue_as :default

  def perform(policy:, issue:, queued_by: nil, queued_at: Time.current)
    return if policy.nil?

    if policy.system_data.has_key?("policy_quote_start_billing")
      policy.system_data["policy_quote_start_billing"]["count"] += 1
      policy.system_data["policy_quote_start_billing"]["history"] << queued_at
    else
      policy.system_data["policy_quote_start_billing"] = {
        count: 1,
        history: [queued_at]
      }
    end

    policy.save!
    policy.reload()

    # send documents
    unless !policy.respond_to?(issue) || policy.carrier_id == 5 # MOOSE WARNING: disable for MSI for now...
      policy.send(issue) unless policy.sent?
      UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver if policy.policy_type_id != 5
      UserCoverages::RentGuaranteeMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver if policy.policy_type_id == 5
    end
    acct = AccountUser.find_by(user_id: policy.primary_user.id, account_id: policy.primary_user.account_users.last&.account_id)
    # enable account users
    acct.update(status: 'enabled') if acct.present? && acct.status != 'enabled'
    # invite policy users
    policy.policy_users.each(&:invite)

    if policy.system_data["policy_quote_start_billing"]["count"].to_i > 1

      content = "Policy ##{ policy.number } Start Billing Job has been queued\n"
      content += "Policy Status: #{ policy.status.titlecase }\n\n\n"
      content += "Issue Method #{ issue }\n"
      content += "Queued By: #{ queued_by }\n"
      content += "Queued At: #{ queued_at.strftime('%B %d, %Y - %l:%M:%S %p UTC:%z') }\n"
      content += "Queue Count: #{ policy.system_data["policy_quote_start_billing"]["count"] }\n"

      if policy.system_data["policy_quote_start_billing"]["history"].count > 1
        content += "Queue History:\n"
        policy.system_data["policy_quote_start_billing"]["history"].reject(&:blank?).each do |entry|
          content += "#{ entry.to_datetime.strftime('%B %d, %Y - %l:%M:%S %p UTC:%z') }\n"
        end
      end

      ActionMailer::Base.mail(
        from: "no-reply-#{ ENV['RAILS_ENV'] }@getcoveredinsurance.com",
        to: "dev@getcovered.io",
        subject: "#{ policy.number } background job queued",
        body: content
      ).deliver_now

    end
  end
end
