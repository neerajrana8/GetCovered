scope module: :policies, path: 'policies' do
  post :list, controller: :policies, action: :list
  post 'show/:id', controller: :policies, action: :show
  post :calculate_cost, controller: :policies, action: :calculate_cost
end
