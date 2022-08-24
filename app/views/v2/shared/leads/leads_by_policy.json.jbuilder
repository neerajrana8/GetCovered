json.array! @leads do |lead|
  json.extract! lead, :id, :email, :created_at, :last_visited_page, :last_visit ,:agency_id, :account_id
  json.agency_name lead&.agency&.title
  json.account_title lead&.account&.title
  json.branding_profile_url lead&.branding_profile&.url

  profile = lead.profile

  json.extract! profile, :first_name, :last_name if profile.present?

  tracking_url = lead.tracking_url

  json.extract! tracking_url, :campaign_source if tracking_url.present?

  if @site_visits.present?
    json.site_visits @site_visits
  end

  json.primary_campaign_name lead&.tracking_url&.campaign_name
  json.primary_campaign_source lead&.tracking_url&.campaign_source
  json.primary_campaign_medium lead&.tracking_url&.campaign_medium
end
