
# Public

post 'qbe/communities/list', 
	to: 'qbe#list', 
	as: 'get_qbe_communities_list'

post 'qbe/communities/show', 
	to: 'qbe#show', 
	as: 'get_qbe_community'

scope module: :public do
  
  resources :addresses,
  	only: [:index]
  
  resources :billing_strategies,
    path: "billing-strategies",
    only: [ :index ]
  
  resources :carrier_class_codes,
    path: "class-codes",
    only: [:index]
  
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
  
  
  post 'policy-quotes/:id/accept', 
  	to: 'policy_quotes#accept', 
  	as: :accept_policy_quote
  
end