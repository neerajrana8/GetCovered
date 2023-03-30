module Policies
  class SendWebhookJob < ApplicationJob
    queue_as :default

    def perform(policy_id: nil)
      unless policy_id.nil?
        policy = ::Policy.find_by(id: policy_id)
        essex_webhook_check = Rails.env == "awsdev" ? 28 : Rails.env == "production" ? 45 : false
        unless essex_webhook_check.nil?
          if policy.account_id == essex_webhook_check
            url = "https://webhooks-chuck-mirror-resapp-a.nestiostaging.com/getcovered-webhooks/policy-status/"
            request = { :number => policy.number, :status => policy.status, :user_email => policy.primary_user().nil? ? nil : policy.primary_user().email,
                        :tcode => policy.primary_user().nil? ? nil : policy.primary_user().integration_profiles.nil? ? nil : policy.primary_user()&.integration_profiles&.first&.external_id }
            event = Event.new(verb: 'post', process: 'policy_status_update_webhook', started: DateTime.current, request: request.to_json.to_s, eventable: policy,
                              endpoint: url)
            result = HTTParty.post(url, :body => request.to_json, :headers => { 'Content-Type' => 'application/json' })
            event.response = result.parsed_response.nil? ? "BLANK" : result.parsed_response.to_json.to_s
            event.status = [200, 202, 204].include?(result.code) ? "success" : "error"
            event.save
          end
        end
      end
    end
  end
end
