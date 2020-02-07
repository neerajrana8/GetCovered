
# User
scope module: :user, path: "user" do
  
  resources :claims,
    only: [ :index, :show, :create ] do
      member do
        post :attach_documents
        delete :delete_documents
      end
    end
  
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
    only: [ :update, :show ] do
  end
end
