module MasterPolicies
  class NotifyAssignedStaffsJob < ApplicationJob
    queue_as :default

    def perform(master_policy_id, invoice_id)
      master_policy = Policy.find_by(id: master_policy_id)
      invoice = Invoice.find_by(id: invoice_id)
      return if master_policy.nil? || invoice.nil? || master_policy.policy_type.designation != 'MASTER'

      master_policy.insurables.each do |insurable|
        insurable.staffs.each do |staff|
          MasterPoliciesMailer.with(master_policy: master_policy, staff: staff, invoice: invoice).bill_master_policy.deliver
        end
      end
    end
  end
end
