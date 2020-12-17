json.extract! tracking_url, :id, :agency_id, :landing_page, :form_url, :branding_url, :campaign_source,
               :campaign_name, :campaign_medium, :campaign_term, :campaign_content,:created_at

if @tracking_url_counts.present?
  json.merge! @tracking_url_counts[tracking_url.id]
end
