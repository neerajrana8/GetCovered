json.data do
  json.array! @users, partial: '/v2/users/user.json', as: :user
end

json.meta @meta
