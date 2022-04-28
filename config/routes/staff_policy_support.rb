scope module: :staff_policy_support, path: "policy-support" do
  resources :policies,
            only: [ :index, :show, :update ]
  post :policies_dashboard_index, action: :index, controller: :policies

  resources :accounts, only: [ :index]
  resources :communities, only: [ :index]

end
