##
# Lease Expiration Check Job

class LeaseExpirationCheckJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default
  
  before_perform :set_leases

  ##
  # LeaseExpirationCheckJob.perform
  #
  # Checks for leases expiring today and
  # activates them
  def perform(*_args)
    # @leases.each(&:deactivate)
    @leases.each do |lease|
      lease.deactivate
      # policy = lease.insurable.policies.current.take

      policies = lease.insurable.policies
      # NOTE: Update user occupation
      lease.update_unit_occupation

      # NOTE: Set lease covered false
      lease.update covered: false

      next if policies.count.zero?

      policies.each do |policy|
        # next unless [PolicyType::MASTER_COVERAGE_ID].include?(policy.policy_type_id)

        if [PolicyType::MASTER_COVERAGE_ID].include?(policy.policy_type_id)
          # NOTE: Call QBE for master_coverage update
          policy.qbe_specialty_evict_master_coverage
        end
      end
    end
  end

  private
    
  def set_leases
    @leases = Lease.current.where(status: 'current').where("end_date < ?", Time.current.to_date)
  end
end
