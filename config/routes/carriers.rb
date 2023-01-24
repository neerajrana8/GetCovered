scope module: :carriers, path: 'carriers' do
  namespace :carrier_policy_types do
    post :list,  action: :list
  end
end
