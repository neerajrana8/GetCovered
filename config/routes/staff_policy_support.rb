scope module: :staff_policy_support, path: "policy-support" do
  resources :policies,
            only: [ :index, :show, :update ]
end