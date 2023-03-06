module MasterPolicies
  # MasterPolicy Issue Job
  class MissingTenantsCoverageJob < ApplicationJob
    prepend Gc
    queue_as :default

    QBE_ID = 2
    BOUND_STATUS_ID = 3

    def perform
      master_policices.find_in_batches do |group|
        group.each do |mpo|
          mpo.insurables.each do |community|
            config = configuration(mpo, community)

            next unless tracking_per_user?(community)
            next unless config
            next unless InsurableType::COMMUNITIES_IDS.include?(community.insurable_type_id)

            leases = leases_without_child_policy(config, community)
            leases.each do |lease|
              begin
                next if unit_affordable?(lease.insurable)

                policies = lease_active_policies(lease)
                user_ids = users_ids_on_active_policies(policies)
                uncovered_users = uncovered_users(lease, user_ids)

                cp = MasterPolicy::ChildPolicyIssuer.call(mpo, lease, uncovered_users)
              rescue StandardError => e
                Rails.logger.info e.to_s
              end
            end
          end
        end
      end
    end

    private

    def tracking_per_user?(community)
      community.account.per_user_tracking
    end

    def uncovered_users(lease, user_ids)
      lease.active_users.where(lessee: true).reject do |user|
        user_ids.include?(user.id)
      end
    end

    def lease_active_policices(lease)
      lease.insurable.policies.where(
        status: Policy.active_statuses,
        policy_type_id: [1, 3]
      )
    end

    def users_ids_on_active_policies(policies)
      PolicyUser.where(policy: policies).pluck(:user_id)
    end

    def policies
      Policy.where(status: BOUND_STATUS_ID)
    end

    def configuration(master_policy, insurable)
      MasterPolicy::ConfigurationFinder.call(master_policy, insurable)
    end

    def master_policices
      Policy.includes(:insurables)
        .where(carrier_id: QBE_ID,
               policy_type_id: PolicyType::MASTER_ID,
               status: 'BOUND')
    end

    def policy_insurables(units_ids)
      PolicyInsurable.joins(:policy).where(insurable_id: units_ids, policy: { status: BOUND_STATUS_ID })
    end

    def units(community)
      Insurable.where(insurable_id: community.id)
    end

    def leases_without_child_policy(_config, community)
      units_ids = units(community).pluck(:id)
      pi = policy_insurables(units_ids)
      leases_with_policies = Lease.where(insurable_id: pi.pluck(:insurable_id).uniq, status: 'current')

      leases_without_policies = if leases_with_policies.count.positive?
        Lease.where(insurable_id: units_ids, status: 'current')
                                  .where('id NOT IN (?)', leases_with_policies.pluck(:id))
      else
        Lease.where(insurable_id: units_ids, status: 'current')
      end

      leases_without_policies
    end

    def matched_leases(config, community)
      Lease.includes(:insurable, :users)
        .where(status: 'current',
               start_date: DateTime.now + config.grace_period.days,
               insurable_id: community.units.pluck(:id),
               covered: false)
    end
  end
end
