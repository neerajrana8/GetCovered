
# Public
scope module: :public do
  
  resources :addresses,
  	only: [:index]
  
  resources :billing_strategies,
    path: "billing-strategies",
    only: [ :index ]
  
  resources :insurables,
    only: [ :index, :show ] do
    member do
			resources :insurable_rates,
				path: 'rates',
				only: [:index]	    
	  end
	end
  
  resources :policy_applications,
    path: "policy-applications",
    only: [ :create, :update, :show, :new ]
  
  resources :policy_quotes,
    path: "policy-quotes",
    only: [ :update, :show ]
  
end