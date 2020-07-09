##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffAccount
    class MasterPoliciesController < StaffAccountController
      def index
        account_id = current_staff.organizable&.id
        master_policies_relation = Policy.where('policy_type_id = ? AND agency_id = ?', PolicyType::MASTER_ID, account_id)
        @master_policies = paginator(master_policies_relation)
      end

      def show
        @master_policy_coverages = @master_policy.policies.where('policy_type_id = ? AND agency_id = ?', 3, @agency.id)
      end
    end
  end
end
