module PolicyApplicationGroups
  # Class that destroyed all related to a policy application group object. I decided not to do
  # it through the depend destroy because in some cases we should not delete some objects
  class TotalDestroy < ActiveInteraction::Base
    object :policy_application_group

    delegate :policy_group_quote, :policy_group, to: :policy_application_group

    def execute
      policy_group&.policies&.destroy_all
      policy_group&.destroy
      policy_group_quote&.invoices&.destroy_all
      policy_group_quote&.policy_quotes&.each do |policy_quote|
        policy_quote&.policy_premium&.destroy
      end
      policy_group_quote&.policy_quotes&.destroy_all
      policy_group_quote&.policy_group_premium&.destroy
      policy_group_quote&.policy_applications&.each do |policy_application|
        policy_application&.policy_users&.destroy_all
      end
      policy_application_group.policy_applications.destroy_all
      policy_group_quote&.destroy
      policy_application_group.destroy
    end
  end
end
