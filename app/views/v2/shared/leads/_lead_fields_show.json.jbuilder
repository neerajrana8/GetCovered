json.extract! lead, :id, :email, :created_at, :last_visited_page, :agency_id
# Coverage Option, Quote
profile = lead.profile
if profile.present?
  json.extract!  profile, :first_name, :last_name
end

first_event =  lead.lead_events.first

if first_event.present? && first_event.policy_type
  json.interested_product first_event.policy_type.title
end

tracking_url =  lead.tracking_url

if tracking_url.present?
  json.extract! tracking_url, :campaign_source, :campaign_medium, :campaign_name
end

