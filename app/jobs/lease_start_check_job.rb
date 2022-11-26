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
  def perform(*_args)
    @leases.each(&:activate)
  end
  
  private
    
  def set_leases
    @leases = Lease.where(status: "pending").where("start_date <= ?", Time.current.to_date)
  end
end
