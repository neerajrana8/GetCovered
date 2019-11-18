
# User
scope module: :user do
  
  resources :claims,
    only: [ :index, :create, :show ]
  
  resources :invoices,
    only: [ :index, :show ]
  
  resources :leases,
    only: [ :index ]
  
  resources :notifications,
    only: [ :update, :index, :show ]
  
  resources :payments,
    only: [ :create, :index, :show ]
  
  resources :policies,
    only: [ :index, :show ]
  
  resources :policy_applications,
    path: "policy-applications",
    only: [ :create, :index, :show ]
  
  resources :policy_quotes,
    path: "policy-quotes",
    only: [ :index, :show ]
  
  resources :users,
    only: [ :update, :show ]
  
end






