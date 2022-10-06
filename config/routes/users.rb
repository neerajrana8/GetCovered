scope module: :users, path: 'users' do
  #resource :users
  post :list, controller: :users, action: :list
  get ':id', controller: :users, action: :show
end
