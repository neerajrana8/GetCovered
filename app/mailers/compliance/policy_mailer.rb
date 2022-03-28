module Compliance
  class PolicyMailer < ApplicationMailer
    include ::ComplianceMethods

    def policy_lapsed(policy:)

    end

    def enrolled_in_master()

    end

    def external_policy_received(policy:)

    end

    def external_policy_accepted(policy:)

    end

    def external_policy_rejected(policy:)

    end

  end
end