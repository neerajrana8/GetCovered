##
# Lease Pre Expiration Check Job

class LeasePreExpirationCheckJob < ApplicationJob
  ##
  # Queue: Default
  queue_as :default

  before_perform :set_leases

  ##
  # LeasePreExpirationCheckJob.perform
  #
  # Checks for leases ending 30 days from now
  # and sends notifications
  def perform(*args)
    @leases.each do |lease|
      LeaseNoticeMailer.with(lease: lease).pre_expiration_notice
      LeaseNoticeMailer.with(lease: lease).pre_expiration_report
    end
  end

  private
    
    def set_leases
      @leases = Lease.current.where(end_date: Time.current.to_date + 30.days)
    end
end
