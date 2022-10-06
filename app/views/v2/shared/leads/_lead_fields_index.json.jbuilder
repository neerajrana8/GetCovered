json.extract! lead, :id, :email, :created_at, :last_visited_page, :last_visit ,:agency_id, :account_id, :branding_profile_id

json.agency_name lead&.agency&.title
json.account_title lead&.account&.title
json.branding_profile_url lead&.branding_profile&.url

profile = lead.profile

json.extract! profile, :first_name, :last_name if profile.present?

json.interested_product lead&.title

tracking_url = lead.tracking_url

json.extract! tracking_url, :campaign_source if tracking_url.present?

if @site_visits.present?
  json.site_visits @site_visits
end

json.primary_campaign_name lead&.tracking_url&.campaign_name
json.primary_campaign_source lead&.tracking_url&.campaign_source
json.primary_campaign_medium lead&.tracking_url&.campaign_medium
#json.premium_total lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total || (last_event&.data.present? ? last_event&.data['premium_total'] : nil)
#json.premium_first lead&.user&.policy_applications&.last&.policy_quotes&.last&.invoices&.first&.total_due || (last_event&.data.present? ? last_event&.data['premium_first'] : nil)
#json.billing_strategy lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.billing_strategy&.title

json.premium_total lead.premium_total #data['premium_total']
json.premium_first lead.data['premium_first']
json.billing_strategy lead&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.billing_strategy&.title
