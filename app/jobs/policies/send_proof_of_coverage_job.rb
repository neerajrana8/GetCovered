module Policies
  class SendProofOfCoverageJob < ApplicationJob
    queue_as :default

    def perform(policy_id)
      policy = ::Policy.find_by(id: policy_id)
      return if policy.nil?

      UserCoverageMailer.with(policy: policy, user: policy.primary_user).all_documents.deliver
    end
  end
end
