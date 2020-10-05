
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

	resources :branding_profiles, only: [:show], path: 'branding-profiles' do
    member do
      get :faqs
    end
  end
	get 'branding-profile', to: 'branding_profiles#show_by_subdomain'
	resources :pages, only: [ :show ]

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

  post '/msi/unit-list',
    to: 'insurables#msi_unit_list',
    as: :msi_unit_list,
    defaults: { format: 'xml' }

  resources :lead_events, only: [:create]
  
  resources :policy_applications,
    path: "policy-applications",
    only: [ :create, :update, :show ] do
      member do
        post :rent_guarantee_complete
      end
      collection do
        post '/new',
          to: 'policy_applications#new',
          as: :new
        post '/get-coverage-options',
          to: 'policy_applications#get_coverage_options',
          as: :get_coverage_options
      end
    end
	
	resources :policy_types, path: 'policy-types', only: [ :index ]	
	
  resources :policy_quotes,
  	path: "policy-quotes",
  	only: [:update] do
		member do
		  post '/accept', 
		  	to: 'policy_quotes#accept', 
		  	as: :accept
      post '/external-payment-auth',
        to: 'policy_quotes#external_payment_auth',
        as: :external_payment_auth
		end  	
	end

  post 'users/check_email', to: '/v2/check_email#user'
  post 'staffs/check_email', to: '/v2/check_email#staff'

  post 'secret_authentication/:secret_token/authenticate', to: '/v2/public/secret_authentication#authenticate'
end
