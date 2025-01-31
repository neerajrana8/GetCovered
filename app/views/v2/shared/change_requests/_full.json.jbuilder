json.partial! 'v2/shared/change_requests/fields.json.jbuilder', change_request: change_request

json.changeable do

  json.partial! "v2/shared/#{change_request.changeable_type.downcase.pluralize}/fields.json.jbuilder",
                change_request.changeable_type.downcase.to_sym => change_request.changeable
end

json.requestable do
  if %w[User Staff].include?(change_request.requestable_type)
    json.partial! "v2/shared/#{change_request.requestable_type.downcase.pluralize}/full.json.jbuilder",
                  change_request.requestable_type.downcase.to_sym => change_request.requestable
  else
    json.partial! "v2/shared/#{change_request.requestable_type.downcase.pluralize}/fields.json.jbuilder",
                  change_request.requestable_type.downcase.to_sym => change_request.requestable
  end
end
