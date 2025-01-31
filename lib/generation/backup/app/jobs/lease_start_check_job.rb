##
# Lease Start Check Job

class LeaseStartCheckJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default
  
  before_perform :set_leases
 
  ##
  # LeaseStartCheckJob.perform
  #
  # Checks for leases starting today and
  # activates them
  def perform(*args)
    @leases.each do |lease|
      lease.activate  
    end
  end
  
  private
    
    def set_leases
      @leases = Lease.approved.where(start_date: Time.current.to_date)
    end
end
