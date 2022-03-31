class BillMasterPoliciesJob < ApplicationJob
  queue_as :default

  def perform(now = false)
    return # temporarily DISABLED because the MP system has been updated drastically
    master_policies.each do |master_policy|
      begin
        invoice = MasterPolicies::GenerateNextInvoice.run!(master_policy: master_policy)
        invoice.pay(stripe_source: :default)
        if now
          ::MasterPolicies::NotifyAssignedStaffsJob.perform_now(master_policy.id, invoice.id)
        else
          ::MasterPolicies::NotifyAssignedStaffsJob.perform_later(master_policy.id, invoice.id)
        end
      rescue StandardError => exception
puts "EXCEPTION #{exception.to_s}"
        Rails.logger.error "Error during the billing of the master policy with the id #{master_policy.id}. Exception #{exception.to_s}."
      end
    end
  end

  private

  def master_policies
    Policy.where(policy_type_id: PolicyType::MASTER_IDS)
  end
end
