module MasterPolicies
  # MasterPolicy Issue Job
  class IssueJob < ApplicationJob
    queue_as :default

    QBE_ID = 2
    BOUND_STATUS_ID = 3
    AFFORDABLE_ID = 'affordable'.freeze

    def perform
      log(self.class.to_s, "Starting #{self.class} #{DateTime.now}")
      master_policices.find_in_batches do |group|
        group.each do |mpo|
          mpo.insurables.each do |community|
            log(self.class.to_s, "\tProcessing '#{community.title}' (ID=#{community.id})")
            log(self.class.to_s, "\t - Checking if type is Community?...#{InsurableType::COMMUNITIES_IDS.include?(community.insurable_type_id)}")
            next unless InsurableType::COMMUNITIES_IDS.include?(community.insurable_type_id)

            config = configuration(mpo, community)
            log(self.class.to_s, "\t - Finding configuration...#{config.id if config}")

            # next if tracking_per_user?(community)
            next unless config

            leases = leases_without_child_policy(config, community)
            log(self.class.to_s, "\t - Finding leases withtout child policies...#{leases.count}")
            leases.each do |lease|
              begin
                log(self.class.to_s, "\t\t Affordable?...#{unit_affordable?(lease.insurable)}")
                next if unit_affordable?(lease.insurable)

                log(self.class.to_s, "\t\t Lease before master policy?...#{lease_started_before_master_policy_started?(lease, mpo)}")
                next unless lease_started_before_master_policy_started?(lease, mpo)

                log(self.class.to_s, "\t\t Tracking per user...#{tracking_per_user?(community)}")
                if tracking_per_user?(community)
                  policies = lease_active_policies(lease)
                  user_ids = users_ids_on_active_policies(policies)
                  log(self.class.to_s, "\t\t Uncovered users ids...IDS=#{user_ids}")
                  uncovered_users = uncovered_users(lease, user_ids)
                  cp = MasterPolicy::ChildPolicyIssuer.call(mpo, lease, uncovered_users)
                else
                  cp = MasterPolicy::ChildPolicyIssuer.call(mpo, lease)
                end
                log(self.class.to_s, "\t\t Child policy issued...#{cp.id if cp}")
              rescue StandardError => e
                Rails.logger.info e.to_s
              end
            end
          end
        end
      end
      log(self.class.to_s, "Finish #{self.class} #{DateTime.now}")
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
