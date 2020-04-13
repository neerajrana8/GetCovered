module PolicyApplications
  class RentGuaranteeCreateJob < ApplicationJob
    queue_as :default

    def perform(all_policy_application_params, policy_users_params)
      ::PolicyApplications::RentGuarantee::Create.run(
        policy_application_params: all_policy_application_params,
        policy_users_params: policy_users_params
      )
    end
  end
end
