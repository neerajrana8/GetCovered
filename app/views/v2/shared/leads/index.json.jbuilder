json.data do
    json.array! @leads,
        partial: 'v2/shared/leads/lead_fields_index.json.jbuilder',
        as: :lead
end

json.meta @meta
