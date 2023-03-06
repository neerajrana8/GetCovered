json.cache! @carriers do
  json.data do
    json.array! @carriers, partial: 'v2/carriers/carrier', as: :carrier
  end

  json.meta @meta
end
