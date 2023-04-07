module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process

  class RenewalIssuer < ApplicationService

    attr_accessor :policy_number
    attr_accessor :policy

    def initialize(policy_number)
      @policy_number = policy_number
      @policy = Policy.find_by_number(@policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      return "Policy with POLICY_NUMBER=#{policy_number} not valid for renewal." unless valid_for_renewal?

      renewal_status_complete = false
      #policy.renew_count is incremented by 1 (if nil, treat as 0 and set to 1)
      renewal_count = policy.renewal_count + 1
      #policy.last_renewed_on is set to the date after the effective date
      renewed_on = policy.effective_date + 1.day
      #policy.status is set to RENEWED
      policy_status = Policy.statuses.values_at('RENEWED')

      #update the policy
      if policy.update_attributes(renewal_count: renewal_count, renewed_on: renewed_on, status: policy_status )
        #Once the update is successful we will need to regenerate the policy document using policy.qbe_issue_policy
        # This will regenerate the policy document and send it to the customer.
        policy.qbe_issue_policy
        renewal_status_complete = true
      else
        #TBD
        renewal_status_complete = false
      end

      renewal_status_complete
    end

    private

    def valid_for_renewal?
      #ensure that the status and billing status show the policy as being
      #in good standing
      # carrier_id: 1
      # policy_type_id: 1
      # policy_in_system: true
      # billing_status: 'current' or 'rescinded'
    end

  end
end
