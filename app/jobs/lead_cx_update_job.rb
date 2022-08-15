# Update LeadEvents count for Lead
# This needs to make dashboards performance better in a common sense
# * Update counters of lead events for lead
# * Prepare timeseries for dashboards charts for lead events per lead
class LeadCxUpdateJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    date_slug_format = '%Y-%m-%d'
    Lead.where.not(status: :converted, archived: false).find_in_batches.with_index do |group, _|
      group.each do |lead|
        lead_events = LeadEvent.where(lead_id: lead.id)
        lead_events_cx = lead_events.count
        time_series = {}
        lead_events_grouped = lead_events.grouped_by_created_at
        lead_events_grouped.each do |g|
          date_slug = g.created_at.strftime(date_slug_format)
          time_series[date_slug] ||= 0
          time_series[date_slug] += g.cx
        end
        lead.update_columns({lead_events_cx: lead_events_cx, lead_events_timeseries: time_series})
      end
    end
  end
end
