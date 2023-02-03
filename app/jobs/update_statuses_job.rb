# class UpdateStatusesJob
#
#  # active_policies
# get all insurables by policy
# lease all leases by insurable
# unit
# for unit
#   if lease
#   if expiration_date < Today and lease.user.profile name != policy.user.profile
#      covered: false
#   else expiration_date > Today and lease.user.profile name = policy.user.profile
#      covered: true
# for lease
#   if policy
#   if expiration_date < Today and lease.user.profile name != policy.user.profile
#      covered: false
#   else expiration_date > Today and lease.user.profile name = policy.user.profile
#      covered: true
#
#
class UpdateStatusesJob < ApplicationJob
  prepend Gc

  queue_as :default

  def perform
    check_date = Time.now

    tenants_mismatched_cx = 0

    skip = false
    unless skip
      active_policies.each do |policy|

        # Unit
        insurable = policy_insurable(policy)

        next unless insurable

        insurable_leases(insurable).each do |lease|
          # Check tenants is matching
          unless tenant_matched?(lease, policy)
            tenants_mismatched_cx += 1
            next
          end

          if lease_shouldbe_covered?(policy, lease, check_date)
            cover_lease(lease)
            make_lease_current(lease)
          else
            uncover_lease(lease)
            make_lease_expired(lease) if lease_expired?(lease, check_date)
          end
        end
      end
    end

    skip = false
    unless skip

      all_units.each do |unit|
        unit_policies(unit).each do |policy|

          if policy_shouldbe_expired?(policy, check_date)
            uncover_unit(unit)
            make_policy_expired_status(policy)
          end

          lease = active_lease(unit)

          if unit_shouldbe_covered?(lease, policy, check_date)
            cover_unit(unit)
          else
            uncover_unit(unit)
          end

        end
      end
    end
    puts stats_as_table
  end
end
