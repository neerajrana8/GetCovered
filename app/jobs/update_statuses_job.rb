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

    skip = false
    unless skip
      puts stats_as_table
      all_units.where.not(account_id: nil).in_batches.each do |batch|
        batch.each do |insurable|
          next unless insurable.account_id

          begin
            Insurables::StatusUpdater.call(insurable, check_date)
          rescue StandardError
            next
          end
        end
        # per_user_tracking = insurable.account.per_user_tracking
        # # Iterate over leases on insurable
        # insurable_leases(insurable).each do |lease|
        #   pi_rels = PolicyInsurable.where(insurable_id: insurable.id)
        #   policies = Policy.where(id: pi_rels.pluck(:policy_id))

        #   all_policy_users = []
        #   policies.each do |policy|
        #     # Gathering users from acitve policies
        #     all_policy_users << policy.users.pluck(:id) if active_policy_statuses.include?(policy.status)
        #   end

        #   lease_users = lease.users.pluck(:id).sort
        #   all_policy_users = all_policy_users.flatten.uniq.sort
        #   intersection = !(all_policy_users & lease_users).empty?

        #   atm = true
        #   atm = (lease_users & all_policy_users) == lease_users if per_user_tracking

        #   if intersection && !lease_expired?(lease, check_date) && atm
        #     cover_lease(lease)
        #     cover_unit(insurable)
        #   else
        #     uncover_lease(lease)
        #     uncover_unit(insurable)
        #   end
        # end
      end

    end
    Rails.cache.clear
    puts stats_as_table
  end
end
