module MasterPolicies
  # MasterPolicy Issue Job
  class IssueJob < ApplicationJob
    prepend Gc

    queue_as :default

    QBE_ID = 2
    BOUND_STATUS_ID = 3
    CHILD_POLICY_TYPE_ID = 3
    AFFORDABLE_ID = 'affordable'.freeze


    def perform
      child_policies = []

      leases = Lease.where(status: 1)

      leases.each do |lease|
        insurable = lease.insurable
        community = insurable.parent_community
        account = insurable.account
        next unless account

        per_user_tracking = account.per_user_tracking

        pi_mpo = PolicyInsurable.find_by(insurable_id: community.id)
        next unless pi_mpo

        mpo = Policy.find(pi_mpo.policy_id)

        next unless mpo
        next if unit_affordable?(insurable)

        next unless lease_started_after_master_policy_started?(lease, mpo)

        cutoff_date = lease.sign_date.nil? ? lease.start_date : lease.sign_date
        config = configuration(mpo, community, cutoff_date)
        next unless config

        atm = true

        if per_user_tracking

          all_policy_users = []
          pi_rels = PolicyInsurable.where(insurable_id: insurable.id)
          policies = Policy.where(id: pi_rels.pluck(:policy_id), status: active_policy_statuses)
          policies.each do |policy|
            # Gathering users from acitve policies
            all_policy_users << policy.users.pluck(:id) if active_policy_statuses.include?(policy.status)
          end

          lease_users = lease.users.pluck(:id).sort
          all_policy_users = all_policy_users.flatten.uniq.sort

          # atm = (lease_users & all_policy_users) == lease_users
          uncovered_users_ids = lease_users - (lease_users & all_policy_users)

          uncovered_users = User.where(id: uncovered_users_ids)
          if uncovered_users&.count&.positive?
            child_policies << MasterPolicy::ChildPolicyIssuer.call(mpo, lease, uncovered_users)
          end
        else

          if !lease_has_child_policy?(lease) && !lease_expired?(lease, DateTime.now)
            child_policies << MasterPolicy::ChildPolicyIssuer.call(mpo, lease)
          end
        end
      end

      child_policies
    end

    private

    def lease_active_policies(lease)
      policies = lease.insurable.policies.where(
        status: Policy.active_statuses,
        policy_type_id: [1, 3]
      )
      policies
    end

    def users_ids_on_active_policies(policies)
      ids = []
      policies.each do |policy|
        ids << policy.policy_users.pluck(:user_id)
      end
      ids
    end

    def tracking_per_user?(community)
      community.account.per_user_tracking
    end


    def uncovered_users(lease, user_ids)
      lease.active_users(lessee: true).select do |user|
        !user_ids.include?(user.id)
      end
    end

    def unit_affordable?(unit)
      return true if unit.special_status == AFFORDABLE_ID

      false
    end

    def lease_started_after_master_policy_started?(lease, mpo)
      return true if lease.start_date >= mpo.effective_date

      false
    end

    def configuration(master_policy, insurable, cutoff_date=false)
      MasterPolicy::ConfigurationFinder.call(master_policy, insurable, cutoff_date)
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

    def child_policy_insurables(units_ids)
      PolicyInsurable.joins(:policy).where(insurable_id: units_ids,
                                           policy: { status: BOUND_STATUS_ID, policy_type_id: CHILD_POLICY_TYPE_ID })
    end

    def units(community)
      Insurable.where(insurable_id: community.id)
    end

    def leases_without_child_policy(community)
      units_ids = units(community).pluck(:id)
      pi = child_policy_insurables(units_ids)
      leases_with_policies = Lease.where(insurable_id: pi.pluck(:insurable_id).uniq, status: 'current')

      leases_without_policies = if leases_with_policies.count.positive?
        Lease.where(insurable_id: units_ids, status: 'current')
                                  .where('id NOT IN (?)', leases_with_policies.pluck(:id))
      else
        Lease.where(insurable_id: units_ids, status: 'current')
      end

      leases_without_policies
    end

    def leases_for_community(community)
      units_ids = units(community).pluck(:id)
      Lease.where(insurable_id: units_ids, status: 'current')
    end

    def lease_has_child_policy?(lease)
      PolicyInsurable.joins(:policy).where(insurable_id: lease.insurable_id,
                                           policy: { status: BOUND_STATUS_ID,
                                                     policy_type_id: CHILD_POLICY_TYPE_ID
                                                   }).any?

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
