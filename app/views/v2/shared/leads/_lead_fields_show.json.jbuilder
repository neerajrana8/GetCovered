json.extract! lead, :id, :email, :created_at, :last_visited_page, :agency_id, :status

json.agency_name lead&.agency&.title

# Coverage Option, Quote
profile = lead.profile
if profile.present?
  json.extract!  profile, :first_name, :last_name
end

last_event =  lead.last_event

if last_event.present? && last_event.policy_type.present?
  json.interested_product last_event.policy_type.title
end

json.tracking_url do
  if lead.tracking_url.present?
    json.partial! 'v2/shared/tracking_urls/tracking_url_index_fields.json.jbuilder',
                  tracking_url: lead.tracking_url
  end
end
