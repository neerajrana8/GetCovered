json.extract! lead, :id, :email, :created_at, :last_visited_page, :last_visit, :agency_id, :account_id, :status, :archived, :branding_profile_id

json.agency_name lead&.agency&.title
json.account_title lead&.account&.title
json.branding_profile_url lead&.branding_profile&.url

# Coverage Option, Quote
profile = lead.profile
if profile.present?
  json.extract! profile, :first_name, :last_name
end

last_event = lead.last_event

if last_event.present? && last_event.policy_type.present?
  json.interested_product last_event.policy_type.title
end

json.primary_campaign_name lead&.tracking_url&.campaign_name
json.premium_total lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total || (last_event&.data.present? ? last_event&.data['premium_total'] : nil)
json.premium_first lead&.user&.policy_applications&.last&.policy_quotes&.last&.invoices&.first&.total_due || (last_event&.data.present? ? last_event&.data['premium_first'] : nil)
json.billing_strategy lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.billing_strategy&.title
json.site_visits visits


json.tracking_url do
  if lead.tracking_url.present?
    json.partial! 'v2/shared/tracking_urls/tracking_url_index_fields.json.jbuilder',
                  tracking_url: lead.tracking_url
  end
end
