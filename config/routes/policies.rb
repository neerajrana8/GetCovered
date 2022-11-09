scope module: :policies, path: 'policies' do
  post :list, controller: :policies, action: :list
  post 'show/:id', controller: :policies, action: :show
end
