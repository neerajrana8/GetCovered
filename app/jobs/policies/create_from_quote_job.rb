module Policies
  class CreateFromQuoteJob < ApplicationJob
    include CarrierPensioPolicyQuote

    queue_as :default

    def perform(policy_quote, status, integration_designation, policy_group = nil)
      policy = policy_quote.build_policy(
        number: policy_number(integration_designation),
        status: status,
        billing_status: 'CURRENT',
        effective_date: policy_quote.policy_application.effective_date,
        expiration_date: policy_quote.policy_application.expiration_date,
        auto_renew: policy_quote.policy_application.auto_renew,
        auto_pay: policy_quote.policy_application.auto_pay,
        policy_in_system: true,
        system_purchased: true,
        billing_enabled: true,
        serviceable: policy_quote.policy_application.carrier.syncable,
        policy_type: policy_quote.policy_application.policy_type,
        policy_group: policy_group,
        agency: policy_quote.policy_application.agency,
        account: policy_quote.policy_application.account,
        carrier: policy_quote.policy_application.carrier
      )
      policy.save
      policy.reload

      policy_quote.policy_application.policy_users.each do |pu|
        pu.update(policy: policy)
        pu.user.convert_prospect_to_customer
      end

      if policy_quote.update(policy: policy) &&
         policy_quote.policy_application.update(policy: policy, status: 'accepted') &&
         policy_quote.policy_premium.update(policy: policy)

        policy.send(issue_policy_method(integration_designation))
        invite_users(policy)
        UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver
      else
        policy_quote.update(status: 'error')
      end
    end

    private

    def invite_users(policy)
      policy.users.each do |user|
        user.invite! unless user.invitation_accepted_at.present?
      end
    end

    def issue_policy_method(integration_designation)
      "#{integration_designation}_issue_policy"
    end

    def policy_number(integration_designation)
      send("#{integration_designation}_generate_number", ::Policy)
    end
  end
end
