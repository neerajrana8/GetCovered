
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

	get 'branding-profile', to: 'branding_profiles#show'

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
  
  resources :policy_quotes,
  	path: "policy-quotes",
  	only: [:update] do
		member do
		  post '/accept', 
		  	to: 'policy_quotes#accept', 
		  	as: :accept			
		end  	
	end

  post 'users/check_email', to: '/v2/check_email#user'
  post 'staffs/check_email', to: '/v2/check_email#staff'
  
end
