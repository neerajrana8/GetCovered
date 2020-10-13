json.extract! lead, :id, :email, :created_at#, :last_visited_page, :campaign_source, Interested Product

profile = lead.profile
if profile.present?
  json.extract!  profile, :first_name, :last_name
end
