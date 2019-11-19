
# Public
scope module: :public do
  
  resources :billing_strategies,
    path: "billing-strategies",
    only: [ :index ]
  
  resources :insurables,
    only: [ :index, :show ]
  
  resources :policy_applications,
    path: "policy-applications",
    only: [ :create, :update, :show, :new ]
  
  resources :policy_quotes,
    path: "policy-quotes",
    only: [ :update, :show ]
  
end






