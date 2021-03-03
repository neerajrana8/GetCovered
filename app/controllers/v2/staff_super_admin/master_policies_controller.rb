##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController
      include MasterPoliciesMethods
    end
  end
end
