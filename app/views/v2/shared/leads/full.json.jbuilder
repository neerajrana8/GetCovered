json.partial! 'v2/shared/leads/fields.json.jbuilder', lead: @lead

json.profile do
  json.partial! 'v2/shared/profiles/fields.json.jbuilder', profile: @lead.profile if @lead.profile.present?
end

json.address do
  json.partial! 'v2/shared/addresses/fields.json.jbuilder', address: @lead.address if @lead.address.present?
end

json.lead_events do
  if @lead.lead_events.any?
    json.array! @lead.lead_events, partial: 'v2/shared/lead_events/fields.json.jbuilder', as: :lead_event
  end
end
