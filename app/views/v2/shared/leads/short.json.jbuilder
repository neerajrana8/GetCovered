json.partial! 'v2/shared/leads/fields.json.jbuilder', lead: @lead

json.lead_events_count @lead.lead_events.count

