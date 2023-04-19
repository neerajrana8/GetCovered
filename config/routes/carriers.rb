scope module: :carriers, path: 'carriers' do
  namespace :carrier_policy_types do
    post :list,  action: :list
  end

  post '/:id/merge', controller: :carriers, action: :merge

  get '/', controller: :carriers, action: :index
end
