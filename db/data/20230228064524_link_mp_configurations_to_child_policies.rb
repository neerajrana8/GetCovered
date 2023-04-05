# frozen_string_literal: true

class LinkMpConfigurationsToChildPolicies < ActiveRecord::Migration[6.1]
  def up
    Policy.master_policy_coverages.find_in_batches(batch_size: 100) do |policies|
      Policy.transaction do
        policies.each do |policy|
          lease = policy.latest_lease(lease_status: ['pending', 'current'])
          available_lease_date = lease.nil? ? DateTime.current.to_date : lease.sign_date.nil? ? lease.start_date : lease.sign_date
          insurable = policy.primary_insurable&.parent_community

          next unless insurable

          master_policy = insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take

          next unless master_policy

          begin
            mpc = MasterPolicy::ConfigurationFinder.call(master_policy, insurable, available_lease_date)
            policy.update!(master_policy_configuration_id: mpc.id) if mpc
          rescue StandardError => e
            puts "Faced an error with policy #{policy.id}: #{e}"
          end
        end
      end
    end
  end

  def down
    Policy.master_policy_coverages.update_all(master_policy_configuration_id: nil)
  end
end
