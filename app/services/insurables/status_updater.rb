module Insurables
  # Service for UpdateStatus for certain Insurable and its leases for certain date
  class StatusUpdater < ApplicationService
    prepend Gc

    attr_accessor :insurable
    attr_accessor :check_date

    def initialize(insurable, check_date=Time.now)
      @insurable = insurable
      @check_date = check_date
    end

    def call
      puts insurable
      return false if insurable.account.nil?

      per_user_tracking = insurable.account.per_user_tracking
      # Iterate over leases on insurable
      insurable_leases(insurable).each do |lease|
        pi_rels = PolicyInsurable.where(insurable_id: insurable.id)
        policies = Policy.where(id: pi_rels.pluck(:policy_id))

        all_policy_users = []
        policies.each do |policy|
          # Gathering users from acitve policies
          all_policy_users << policy.users.pluck(:id) if active_policy_statuses.include?(policy.status)
        end

        lease_users = lease.users.pluck(:id).sort
        all_policy_users = all_policy_users.flatten.uniq.sort
        intersection = !(all_policy_users & lease_users).empty?

        atm = true
        atm = (lease_users & all_policy_users) == lease_users if per_user_tracking

        if intersection && !lease_expired?(lease, check_date) && atm
          cover_lease(lease)
          cover_unit(insurable)
        else
          uncover_lease(lease)
          uncover_unit(insurable)
        end
      end
    end


  end
end
