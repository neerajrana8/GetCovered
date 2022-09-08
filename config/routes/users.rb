scope module: :users, path: 'users' do
  #resource :users
  post :list, controller: :users, action: :list
end
