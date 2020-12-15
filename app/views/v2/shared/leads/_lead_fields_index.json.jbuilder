json.extract! lead, :id, :email, :created_at, :last_visited_page, :last_visit ,:agency_id

json.agency_name lead&.agency&.title

profile = lead.profile
if profile.present?
  json.extract!  profile, :first_name, :last_name
end

last_event =  lead.last_event

if last_event.present? && last_event.policy_type.present?
  json.interested_product last_event.policy_type.title
end

tracking_url =  lead.tracking_url

if tracking_url.present?
  json.extract! tracking_url, :campaign_source
end
