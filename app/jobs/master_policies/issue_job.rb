module MasterPolicies
  # MasterPolicy Issue Job
  class IssueJob < ApplicationJob
    queue_as :default

    QBE_ID = 2
    BOUND_STATUS_ID = 3
    AFFORDABLE_ID = 'affordable'.freeze

    def perform
      master_policices.find_in_batches do |group|
        group.each do |mpo|
          mpo.insurables.each do |community|
            next unless InsurableType::COMMUNITIES_IDS.include?(community.insurable_type_id)

            config = configuration(mpo, community)

            next unless config
            next unless InsurableType::COMMUNITIES_IDS.include?(community.insurable_type_id)

            leases = leases_without_child_policy(config, community)
            leases.each do |lease|
              begin
                next if unit_affordable?(lease.insurable)
                next unless lease_started_before_master_policy_started?(lease, mpo)

                cp = MasterPolicy::ChildPolicyIssuer.call(mpo, lease)
              rescue StandardError => e
                Rails.logger.info e.to_s
              end
            end
          end
        end
      end
    end

    private

    def unit_affordable?(unit)
      return true if unit.special_status == AFFORDABLE_ID

      false
    end

    def lease_started_before_master_policy_started?(lease, mpo)
      return true if lease.start_date >= mpo.effective_date

      false
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
