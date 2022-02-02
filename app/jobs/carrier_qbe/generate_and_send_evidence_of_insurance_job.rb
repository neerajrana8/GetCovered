module CarrierQBE
  class GenerateAndSendEvidenceOfInsuranceJob < ApplicationJob

    queue_as :default

    def perform(policy)
      raise ArgumentError.new("Policy must be specified") if policy.nil? || !policy.is_a?(Policy)
      raise ArgumentError.new("Policy must be residential") unless policy.policy_type_id == 1
      raise ArgumentError.new("Policy must be issued by QBE") unless policy.carrier_id == 1

      policy.reload()
      policy.qbe_issue_policy() if policy.absent?
    end

  end
end