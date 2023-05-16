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
  # @todo blocked by https://app.asana.com/0/483084812253981/1155162983197689
  def perform(*_args)
    @leases.each do |lease|
      LeaseNoticeMailer.with(lease: lease).pre_expiration_notice
      LeaseNoticeMailer.with(lease: lease).pre_expiration_report
    end
  end

  private
    
  def set_leases
    @leases = Lease.current.where(end_date: Time.current.to_date + 30.days, month_to_month: false)
  end
end
