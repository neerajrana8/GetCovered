json.cache! policies do
  json.data do
    json.array! policies, partial: 'v2/policies/policy', as: :policy
  end

  json.meta @meta
end
