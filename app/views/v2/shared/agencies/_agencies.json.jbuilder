if agencies.present?
  json.array! agencies do |agency|
    json.partial! "v2/shared/agencies/agency_short_fields",
                  agency: agency
  end
end
