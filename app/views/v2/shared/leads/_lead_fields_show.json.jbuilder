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

json.tracking_url do
  if lead.tracking_url.present?
    json.partial! 'v2/shared/tracking_urls/tracking_url_index_fields.json.jbuilder',
                  tracking_url: lead.tracking_url
  end
end
