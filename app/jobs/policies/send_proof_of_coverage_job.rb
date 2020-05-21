module Policies
  class SendProofOfCoverageJob < ApplicationJob
    def perform(policy_id)
      policy = ::Policy.find_by(id: policy_id)
      return if policy.nil?

      UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver
    end
  end
end