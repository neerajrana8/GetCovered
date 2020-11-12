class LeadsStatusUpdateJob < ApplicationJob
  queue_as :default
  before_perform :set_lost_leads
  before_perform :set_return_leads

  #need to add klaviyo batch update
  def perform(*_args)
    @lost_leads.update_all(status: 'lost')
    #@return_leads.update_all(status: 'return')
  end

  private

  def set_lost_leads
    # grab all leads which not active last 90 days
    @lost_leads = Lead.where(status: 'prospect').where('last_visit < ?', 90.days.ago)
  end

  #need to clarify with miguel
  def set_return_leads
    # grab all leads which was not active less than 90 days and was active today
    @return_leads = Lead.includes(:lead_events).where(status: 'prospect')
                        .where('last_visit > ?', 90.days.ago)
    #.where('lead_events.created_at!=DATE(leads.last_visit)')
  end


end

