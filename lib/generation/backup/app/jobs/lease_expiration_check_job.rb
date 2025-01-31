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
  def perform(*args)
    @leases.each do |lease|
      lease.deactivate
    end
  end

  private
    
    def set_leases
      @leases = Lease.current.where(end_date: Time.current.to_date - 1.day)
    end
end
