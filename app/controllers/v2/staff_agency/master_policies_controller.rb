##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController
      include MasterPoliciesMethods

      check_privileges 'policies.master'
    end
  end
end
