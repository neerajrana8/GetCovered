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
      policy = lease.insurable.policies.current.take

      # NOTE: Update user occupation
      lease.update_unit_occupation

      # NOTE: Set lease covered false
      lease.update covered: false

      next if policy.blank?
      next unless [PolicyType::MASTER_COVERAGE_ID, PolicyType::RESIDENTIAL_ID].include?(policy.policy_type_id)

      # NOTE: Set policy status to CANCELLED
      policy.update status: 'CANCELLED'

      # NOTE: Call QBE for master_coverage update
      policy.qbe_specialty_evict_master_coverage if policy.policy_type_id == PolicyType::MASTER_COVERAGE_ID
    end
  end

  private
    
  def set_leases
    @leases = Lease.current.where(status: 'current').where("end_date < ?", Time.current.to_date)
  end
end
