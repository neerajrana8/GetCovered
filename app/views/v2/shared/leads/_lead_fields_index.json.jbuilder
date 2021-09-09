json.extract! lead, :id, :email, :created_at, :last_visited_page, :last_visit ,:agency_id, :account_id

json.agency_name lead&.agency&.title
json.account_title lead&.account&.title
json.branding_profile_url lead&.branding_profile&.url

profile = lead.profile
if profile.present?
  json.extract!  profile, :first_name, :last_name
end

last_event = lead.last_event

if last_event.present? && last_event.policy_type.present?
  json.interested_product last_event.policy_type.title
end

tracking_url = lead.tracking_url

if tracking_url.present?
  json.extract! tracking_url, :campaign_source
end

if @site_visits.present?
  json.site_visits @site_visits
end

json.primary_campaign_name lead&.tracking_url&.campaign_name
json.primary_campaign_source lead&.tracking_url&.campaign_source
json.primary_campaign_medium lead&.tracking_url&.campaign_medium
json.premium_total lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total || (last_event&.data.present? ? last_event&.data['premium_total'] : nil)
json.premium_first lead&.user&.policy_applications&.last&.policy_quotes&.last&.invoices&.first&.total_due || (last_event&.data.present? ? last_event&.data['premium_first'] : nil)
json.billing_strategy lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.billing_strategy&.title
