json.accounts do
  if user.accounts.present?
    json.array! user.accounts do |account|
      json.partial! "v2/shared/accounts/short_fields",
                    account: account
    end
  end
end

if user.agencies
  subagencies = []
  agencies = []
  user.agencies.each do |agency|
    if agency.agency
      subagencies << agency
      agencies << agency.agency
    else
      agencies << agency
    end
  end
  subagencies = subagencies.uniq
  agencies = agencies.uniq
  json.subagencies do
    json.partial! "v2/shared/agencies/agencies",
                  agencies: subagencies
  end
  json.agencies do
    json.partial! "v2/shared/agencies/agencies",
                  agencies: agencies
  end
end
