json.cache! @insurables do
  json.data do
    json.array! @insurables, partial: 'v2/insurables/insurable', as: :insurable
  end

  json.meta @meta
end
