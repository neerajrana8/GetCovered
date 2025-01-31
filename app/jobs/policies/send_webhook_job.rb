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
            prod_url = "https://webhooks.nestiolistings.com/getcovered-webhooks/18855/policy-status/"
            env_url = if ["awsdev", "production"].include?(Rails.env)
                        Rails.env == "awsdev" ? url : prod_url
                      else
                        "http://0.0.0.0:300"
                      end

            request = {
              :number => policy.number,
              :status => policy.status,
              :effective_date => policy.effective_date,
              :community_yardi_id => policy.primary_insurable.parent_community.integration_profiles.nil? ? nil : policy.primary_insurable.parent_community.integration_profiles.first.external_id,
              :users => Array.new
            }

            policy.users.each do |user|
              tcode = IntegrationProfile.exists?(profileable_type: "User", profileable_id: user.id) ? user.integration_profiles.first.external_id : nil
              request[:users] << tcode
            end

            event = Event.new(verb: 'post', process: 'policy_status_update_webhook', started: DateTime.current, request: request.to_json.to_s, eventable: policy,
                              endpoint: env_url)
            result = HTTParty.post(env_url, :body => request.to_json, :headers => { 'Content-Type' => 'application/json' })
            event.response = result.parsed_response.nil? ? "BLANK" : result.parsed_response.to_json.to_s
            event.status = [200, 202, 204].include?(result.code) ? "success" : "error"
            event.save
          end
        end
      end
    end
  end
end
