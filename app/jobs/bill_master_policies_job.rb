class BillMasterPoliciesJob < ApplicationJob
  queue_as :default

  def perform
    master_policies.each do |master_policy|
      begin
        invoice = MasterPolicies::GenerateNextInvoice.run!(master_policy: master_policy)
        invoice.pay(stripe_source: :default)
      rescue StandardError => exception
        Rails.logger.error "Error during the billing of the master policy with the id #{master_policy.id}. Exception #{exception.to_s}."
      end
    end
  end

  private

  def master_policies
    Policy.where(policy_type_id: PolicyType::MASTER_ID)
  end
end
