module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process

  class RenewalIssuer < ApplicationService

    attr_accessor :policy_number
    attr_accessor :premium
    attr_accessor :policy

    def initialize(policy_number, premium)
      @policy_number = policy_number
      @premium = premium.to_i * 100
      @policy = Policy.find_by_number(@policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      return "Policy with POLICY_NUMBER=#{policy_number} not valid for renewal." unless valid_for_renewal?

      renewal_status_complete = false

      refresh_rates_status = PolicyRenewal::RefreshRatesService.call(policy.number)
      invoices_generation_status = PolicyRenewal::RenewedInvoicesGeneratorService.call(policy.number)

      @relevant_premium = @policy.policy_premiums.order(created_at: :desc).first
      @premium_difference = @premium.nil? ? nil : @premium - @relevant_premium.total_premium

      #policy.renew_count is incremented by 1 (if nil, treat as 0 and set to 1)
      renewal_count = policy.renew_count.blank? ? 1 : policy.renew_count + 1
      #policy.last_renewed_on is set to the date after the effective date
      new_effective_date = policy.renewal_date
      renewed_on = new_effective_date + 1.day
      new_expiration_date = new_effective_date + 1.year
      #policy.status is set to RENEWED
      policy_status = Policy.statuses.values_at('RENEWED').first

      #update the policy
      if refresh_rates_status && invoices_generation_status && policy.update(renew_count: renewal_count, last_renewed_on: renewed_on,
                                                                             status: policy_status, expiration_date: new_expiration_date)
        #Once the update is successful we will need to regenerate the policy document using policy.qbe_issue_policy
        # This will regenerate the policy document and send it to the customer.
        # policy.qbe_issue_policy
        # RenewalMailer.with(policy: policy).policy_renewal_success.deliver_later
        prepare_invoices()
        update_premium() unless @premium_difference.nil?
        start_billing()
        renewal_status_complete = true
      else
        #TBD
        # RenewalMailer.with(policy: policy).policy_renewal_failed.deliver_later
        renewal_status_complete = false

      end

      renewal_status_complete
    end

    private

    def prepare_invoices
      @policy.invoices.where(status: 'quoted').update_all(status: 'upcoming')
      @policy.invoices.where(status: 'upcoming', due_date: @policy.created_at..DateTime.current.to_date)
             .update_all(status: 'available')
    end

    def update_premium
      ppi = @relevant_premium.policy_premium_items.where(category: 'premium').take
      ppi.change_remaining_total_by(@premium_difference,
                                    clamp_start_date_to_effective_date: false,
                                    clamp_start_date_to_today: true,
                                    clamp_start_date_to_first: false)
    end

    def start_billing

    end

    def valid_for_renewal?
      return false if policy.carrier_id.blank? || policy.billing_status.blank?
      policy.carrier_id == 1 &&
        policy.policy_type_id == ::PolicyType::RESIDENTIAL_ID &&
        policy.policy_in_system == true &&
        policy.auto_renew == true &&
        ['CURRENT', 'RESCINDED'].include?(policy.billing_status)
    end

  end
end
