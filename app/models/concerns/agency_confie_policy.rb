#
# AgencyConfiePolicy Concern
# file: app/models/concerns/agency_confie_policy.rb

module AgencyConfiePolicy
  extend ActiveSupport::Concern

  
  def run_postbind_hooks
    super if defined?(super)
    inform_confie_of_policy if pol.agency_id == ConfieService.agency_id && pol.is_active?
  end

  def inform_confie_of_policy
    cs = ConfieService.new
    cs.build_request(:online_policy_sale, policy: self, line_breaks: true)
    event = self.events.new(cs.event_params)
    event.started = Time.now
    result = cs.call
    event.completed = Time.now
    event.response = result[:response].response.body
    event.status = result[:error] ? 'error' : 'success'
    event.save
  end
  
end
