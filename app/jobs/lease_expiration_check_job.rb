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
    @leases.each(&:deactivate)
  end

  private
    
  def set_leases
    @leases = Lease.current.where(status: 'current').where("end_date < ?", Time.current.to_date)
  end
end
